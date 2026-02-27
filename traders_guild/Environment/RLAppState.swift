//
//  RLAppState.swift
//  traders_guild
//
//  CLEAN REBUILD - Uses flat DTOs that match backend exactly.
//

import Foundation
import SwiftUI
import Combine
import UIKit

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

    /// User settings (privacy/data preferences)
    @Published var userSettings: RLUserSettingsDTO?

    /// Whether presence indicators should be used in the UI
    var shouldShowPresence: Bool {
        userSettings?.showOnlineStatus ?? true
    }

    func effectiveOnlineStatus(userId: UUID, fallback: Bool) -> Bool {
        guard shouldShowPresence else { return false }
        if presenceByUserId.isEmpty {
            return fallback
        }
        return presenceByUserId[userId] ?? false
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
    private var transitionMinimumDismissAt: Date?
    private var isFinalizingOnboarding: Bool = false
    
    @Published var showGuildSelectionSheet: Bool = false

    /// Keeps auth/signup onboarding in ContentView even after auth tokens are issued.
    @Published var isOnboardingFlowActive: Bool = false

    /// Password reset token captured from deep-link.
    @Published var pendingPasswordResetToken: String?
    
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

    @Published var notificationStats: RLNotificationStatsDTO?
    
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
        setupGuildEventListeners()
        
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
        userSettings = nil
        userGuilds = []
        showGuildSelectionSheet = false
        isHandlingAuthFlow = false
        isOnboardingFlowActive = false
        pendingPasswordResetToken = nil
        
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
        DispatchQueue.main.async {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            RealTimeService.shared.connect(token: accessToken)
        }
    }
    
    // ================================================================================================
    // MARK: - Transition Management
    // ================================================================================================
    
    func finishTransition() {
        showingTransition = false
        hasCompletedInitialLoad = true
        transitionMinimumDismissAt = nil
    }
    
    func chartDidBecomeReady() {
        isChartReady = true
    }
    
    func resetChartReadyState() {
        isChartReady = false
        transitionMinimumDismissAt = nil
    }
    
    func showTransitionForChartLoad(minimumDuration: TimeInterval = 0) {
        isChartReady = false
        showingTransition = true
        transitionMinimumDismissAt = minimumDuration > 0 ? Date().addingTimeInterval(minimumDuration) : nil
    }

    func transitionMinimumRemaining() -> TimeInterval {
        guard let transitionMinimumDismissAt else { return 0 }
        return max(0, transitionMinimumDismissAt.timeIntervalSinceNow)
    }

    func hasSatisfiedTransitionMinimum() -> Bool {
        transitionMinimumRemaining() <= 0
    }
    
    // ================================================================================================
    // MARK: - Error Management
    // ================================================================================================

    private func isCancellationLikeError(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        if case let APIError.networkError(message) = error {
            let lower = message.lowercased()
            if lower.contains("cancelled") || lower.contains("canceled") {
                return true
            }
        }
        return false
    }
    
    func showError(_ error: Error, title: String = "Error", style: RLAlertDisplayStyle = .alert) {
        if isCancellationLikeError(error) {
            return
        }

        let alert = RLAppAlert(
            title: title,
            message: error.localizedDescription,
            severity: .error,
            style: style
        )
        currentAlert = alert
        if style == .toast {
            ToastWindowManager.shared.showToast(alert) { [weak self] in self?.clearAlert() }
        }
    }
    
    func showError(title: String, message: String, severity: RLAlertSeverity = .error, style: RLAlertDisplayStyle = .alert) {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: severity,
            style: style
        )
        currentAlert = alert
        if style == .toast {
            ToastWindowManager.shared.showToast(alert) { [weak self] in self?.clearAlert() }
        }
    }
    
    func showSuccess(_ message: String, title: String = "Success") {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: .success,
            style: .toast
        )
        currentAlert = alert
        ToastWindowManager.shared.showToast(alert) { [weak self] in self?.clearAlert() }
    }
    
    func showInfo(_ message: String, title: String = "Info") {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: .info,
            style: .toast
        )
        currentAlert = alert
        ToastWindowManager.shared.showToast(alert) { [weak self] in self?.clearAlert() }
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
    func signUp(data: RLSignupData, beginOnboarding: Bool = false) async throws {
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
            self.isSessionRestored = true
            
            showSuccess("Welcome to Traders Guild, \(response.user.username)!")
            if beginOnboarding {
                isOnboardingFlowActive = true
            } else {
                showTransitionForChartLoad()
            }
            
        } catch {
            showError(error, title: "Signup Failed", style: .alert)
            throw error
        }
    }
    
    /// Login with identifier (email or username) and password
    func login(identifier: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        isHandlingAuthFlow = true  // ← Prevent race conditions
        
        defer {
            isLoading = false
            // Note: Don't clear isHandlingAuthFlow here if showing sheet
        }
        
        do {
            // Call real API
            let response = try await realApi.login(identifier: identifier, password: password)
            
            // Store tokens
            self.accessToken = response.tokens.accessToken
            self.refreshToken = response.tokens.refreshToken
            
            // Set user (this triggers isAuthenticated = true)
            self.currentUser = response.user
            // Always require explicit guild selection post-login.
            self.currentGuild = nil
            self.currentMembership = nil
            self.isSessionRestored = true
            
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
            } else {
                print("🔐 Login: Guild selection required (\(userGuilds.count) guilds)")
                showGuildSelectionSheet = true
                isHandlingAuthFlow = false
            }

            // Fetch notifications
            subscribeToNotifications()
            
            print("🔐 Login: Final state - currentGuild: \(currentGuild?.name ?? "nil"), showSheet: \(showGuildSelectionSheet)")
            
            isOnboardingFlowActive = false
            showSuccess("Welcome back, \(response.user.username)!")
            
        } catch {
            isHandlingAuthFlow = false  // ← Clear flag on error
            showError(error, title: "Login Failed", style: .alert)
            throw error
        }
    }

    /// Backward-compatible login wrapper for older call sites.
    func login(email: String, password: String) async throws {
        try await login(identifier: email, password: password)
    }
    
    /// Logout and clear session
    func logout() {
        // Unsubscribe from notifications
        unsubscribeFromNotifications()
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
        isOnboardingFlowActive = false
        pendingPasswordResetToken = nil
        presenceByUserId.removeAll()
        currentPresenceChannel = nil
        
        
        
        clearAllKeychain()
        resetChartReadyState()
        
        showInfo("You've been logged out")
    }

    func completeOnboardingAndEnterApp() {
        guard !isFinalizingOnboarding else { return }
        isFinalizingOnboarding = true

        Task {
            defer { isFinalizingOnboarding = false }

            if currentUser == nil, accessToken != nil {
                if let hydratedUser = try? await realApi.getCurrentUser() {
                    currentUser = hydratedUser
                }
            }

            guard isAuthenticated else {
                showError(
                    title: "Signup session not ready",
                    message: "We could not finalize your account session. Please sign in and continue.",
                    severity: .warning,
                    style: .alert
                )
                return
            }

            if currentGuild == nil {
                if userGuilds.isEmpty {
                    try? await fetchUserGuilds()
                }

                if currentGuild == nil, let firstGuild = userGuilds.first {
                    selectGuild(firstGuild, showTransition: false)
                }

                if currentGuild == nil {
                    if let fallbackGuild = try? await assignOnboardingGuild(showTransition: false) {
                        selectGuild(fallbackGuild, showTransition: false)
                    }
                }
            }

            guard currentGuild != nil else {
                showError(
                    title: "Guild selection required",
                    message: "Please select a guild to continue.",
                    severity: .warning,
                    style: .alert
                )
                showGuildSelectionSheet = true
                return
            }

            isOnboardingFlowActive = false
            showTransitionForChartLoad(minimumDuration: 2.5)
        }
    }

    func setPendingPasswordResetToken(_ token: String?) {
        pendingPasswordResetToken = token
    }
    
    /// Restore session from keychain
    func restoreSession() async {
        print("🔄 restoreSession: Starting...")

        // Do not let background restoration clobber an active auth/signup flow.
        if isAuthenticated || isHandlingAuthFlow || isOnboardingFlowActive {
            isSessionRestored = true
            return
        }
        
        // Restore tokens
        let storedAccessToken = getTokenFromKeychain()
        let storedRefreshToken = getRefreshTokenFromKeychain()

        if storedAccessToken != nil {
            print("🔄 restoreSession: Found access token")
        }
        if storedRefreshToken != nil {
            print("🔄 restoreSession: Found refresh token")
        }

        var resolvedAccessToken = storedAccessToken
        var resolvedRefreshToken = storedRefreshToken

        // Set tokens on realApi and try to refresh before publishing accessToken
        if let access = storedAccessToken, let refresh = storedRefreshToken {
            realApi.setTokens(access: access, refresh: refresh)
            print("🔄 restoreSession: Tokens set on API service")
            do {
                let refreshed = try await realApi.refreshAccessToken()
                resolvedAccessToken = refreshed.accessToken
                resolvedRefreshToken = refreshed.refreshToken
                print("🔄 restoreSession: Tokens refreshed")
            } catch {
                print("⚠️ restoreSession: Token refresh failed: \(error)")
            }
        } else if let access = storedAccessToken {
            // Fallback - at least set access token
            realApi.setAccessToken(access)
        }

        // If auth/signup completed while we were restoring, keep live in-memory state.
        if isAuthenticated || isHandlingAuthFlow || isOnboardingFlowActive || currentUser != nil {
            print("🔄 restoreSession: Skipping apply - live auth state already established")
            isSessionRestored = true
            return
        }

        // Publish tokens after refresh attempt so WS connects with valid token
        if let access = resolvedAccessToken {
            self.accessToken = access
        }
        if let refresh = resolvedRefreshToken {
            self.refreshToken = refresh
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

        if currentUser != nil {
            do {
                userSettings = try await realApi.getUserSettings()
            } catch {
                print("⚠️ restoreSession: Failed to fetch user settings: \(error)")
            }
            subscribeToNotifications()
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
    func selectGuild(
        _ guildWithMembership: RLGuildWithMembership,
        showTransition: Bool = false,
        minimumTransitionDuration: TimeInterval = 0
    ) {
        if showTransition {
            showTransitionForChartLoad(minimumDuration: minimumTransitionDuration)
        }
        
        self.currentGuild = guildWithMembership.guild
        self.currentMembership = guildWithMembership.membership
        
        // Dismiss the sheet if it's open
        if showGuildSelectionSheet {
            showGuildSelectionSheet = false
        }
        
        // Refresh current user's guild reputation from reputation-service so UI never shows stale 0
        Task { await refreshCurrentGuildReputation() }
    }
    
    /// Refreshes current user's guild reputation and accuracy from reputation-service and updates currentMembership.
    /// Call after selecting a guild, when app becomes active, and when opening profile so UI never shows stale 0 or missing accuracy.
    func refreshCurrentGuildReputation() async {
        guard let guild = currentGuild, let membership = currentMembership else { return }
        var newReputation: Int? = nil
        var newAccuracyRate: Double? = nil
        do {
            let profile = try await realApi.getMyGuildReputation(guildId: guild.id)
            newReputation = profile.reputation
        } catch { /* non-fatal */ }
        do {
            let accuracyProfile = try await realApi.getMyGuildAccuracy(guildId: guild.id)
            newAccuracyRate = accuracyProfile.accuracyRate
        } catch { /* non-fatal */ }
        let rep = newReputation ?? membership.reputation
        let acc = newAccuracyRate ?? membership.accuracyRate
        if rep != membership.reputation || acc != membership.accuracyRate {
            currentMembership = membership.withReputation(rep, accuracyRate: acc)
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
    func fetchJoinableGuilds(
        search: String? = nil,
        isOpen: Bool? = nil,
        language: String? = nil,
        location: String? = nil,
        sort: String? = nil
    ) async throws -> [RLGuildDTO] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let guilds = try await realApi.getJoinableGuilds(
                search: search,
                isOpen: isOpen,
                language: language,
                location: location,
                sort: sort
            )
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

    /// Fetch open guilds available before authentication (signup discovery).
    func fetchPublicOpenGuilds(
        search: String? = nil,
        language: String? = nil,
        location: String? = nil,
        sort: String? = nil
    ) async throws -> [RLGuildDTO] {
        isLoading = true
        defer { isLoading = false }

        do {
            let guilds = try await realApi.getPublicOpenGuilds(
                search: search,
                language: language,
                location: location,
                sort: sort
            )
            print("🏰 fetchPublicOpenGuilds: Found \(guilds.count) open guilds")
            return guilds
        } catch {
            showError(error, title: "Failed to Fetch Open Guilds", style: .toast)
            throw error
        }
    }

    /// Join a guild - returns the combined guild with membership
    func joinGuild(guildId: UUID, showTransition: Bool = true) async throws -> RLGuildWithMembership {
        do {
            let response = try await realApi.joinGuild(guildId: guildId)
            let guildWithMembership = response.asGuildWithMembership
            
            // Add to local guild list
            userGuilds.append(guildWithMembership)
            
            // Select the newly joined guild.
            selectGuild(guildWithMembership, showTransition: showTransition)
            
            showSuccess("Joined \(guildWithMembership.guild.name) successfully!")
            return guildWithMembership
        } catch {
            if case APIError.badRequest(let detail) = error, detail == "approval_required" {
                showError(
                    title: "Approval Required",
                    message: "This guild is private. Submit a join request instead.",
                    severity: .warning,
                    style: .toast
                )
                throw error
            }
            if case APIError.serverError(let statusCode, let detail) = error, statusCode == 403 {
                if detail == "approval_required" {
                    showError(
                        title: "Approval Required",
                        message: "This guild is private. Submit a join request instead.",
                        severity: .warning,
                        style: .toast
                    )
                    throw error
                }
                if detail.hasPrefix("kicked_cooldown_active_until:") {
                    showError(
                        title: "Rejoin Cooldown Active",
                        message: "You were recently removed from this guild and can rejoin after the cooldown, unless invited by an owner/admin.",
                        severity: .warning,
                        style: .toast
                    )
                    throw error
                }
            }
            showError(error, title: "Failed to Join Guild", style: .toast)
            throw error
        }
    }

    /// Assign user to an onboarding fallback guild (no-open-guild signup path).
    func assignOnboardingGuild(showTransition: Bool = false) async throws -> RLGuildWithMembership {
        do {
            let response = try await realApi.assignOnboardingGuild()
            let guildWithMembership = response.asGuildWithMembership

            if let existingIndex = userGuilds.firstIndex(where: { $0.guild.id == guildWithMembership.guild.id }) {
                userGuilds[existingIndex] = guildWithMembership
            } else {
                userGuilds.append(guildWithMembership)
            }

            selectGuild(guildWithMembership, showTransition: showTransition)
            return guildWithMembership
        } catch {
            showError(error, title: "Failed to Assign Onboarding Guild", style: .toast)
            throw error
        }
    }
    
    /// Create a new guild - returns the combined guild with membership
    func createGuild(
        name: String,
        description: String?,
        isOpen: Bool,
        language: String? = nil,
        location: String? = nil,
        joinQuestions: [RLGuildJoinQuestionInputDTO] = []
    ) async throws -> RLGuildWithMembership {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await realApi.createGuild(
                name: name,
                description: description,
                isOpen: isOpen,
                language: language,
                location: location,
                joinQuestions: joinQuestions
            )
            let guildWithMembership = response.asGuildWithMembership
            
            // Add to local guild list
            userGuilds.append(guildWithMembership)
            
            // Select the newly created guild (show transition)
            selectGuild(guildWithMembership, showTransition: true)
            
            showSuccess("Created \(guildWithMembership.guild.name) successfully!")
            return guildWithMembership
        } catch {
            if case APIError.badRequest(let detail) = error, detail == "guild_create_limit_reached" {
                showError(
                    title: "Guild Limit Reached",
                    message: "You can own up to 5 active guilds.",
                    severity: .warning,
                    style: .toast
                )
                throw error
            }
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

    func getGuildJoinQuestions(guildId: UUID) async throws -> [RLGuildJoinQuestionDTO] {
        do {
            let response = try await realApi.getGuildJoinQuestions(guildId: guildId)
            return response.questions
        } catch {
            showError(error, title: "Failed to Load Questions", style: .toast)
            throw error
        }
    }

    func submitGuildJoinRequest(guildId: UUID, note: String?, answers: [RLGuildJoinRequestAnswerInputDTO]) async throws -> RLGuildJoinRequestDTO {
        do {
            let result = try await realApi.createGuildJoinRequest(guildId: guildId, note: note, answers: answers)
            showSuccess("Join request submitted")
            return result
        } catch {
            showError(error, title: "Failed to Submit Request", style: .toast)
            throw error
        }
    }

    func getGuildJoinRequests(guildId: UUID, status: String? = "pending") async throws -> [RLGuildJoinRequestDTO] {
        do {
            let response = try await realApi.getGuildJoinRequests(guildId: guildId, status: status)
            return response.requests
        } catch {
            showError(error, title: "Failed to Load Join Requests", style: .toast)
            throw error
        }
    }

    func approveGuildJoinRequest(guildId: UUID, requestId: UUID, reviewNote: String? = nil) async throws -> RLGuildJoinRequestDTO {
        do {
            let response = try await realApi.approveGuildJoinRequest(
                guildId: guildId,
                requestId: requestId,
                reviewNote: reviewNote
            )
            showSuccess("Join request approved")
            return response
        } catch {
            showError(error, title: "Failed to Approve Request", style: .toast)
            throw error
        }
    }

    func declineGuildJoinRequest(guildId: UUID, requestId: UUID, reviewNote: String? = nil) async throws -> RLGuildJoinRequestDTO {
        do {
            let response = try await realApi.declineGuildJoinRequest(
                guildId: guildId,
                requestId: requestId,
                reviewNote: reviewNote
            )
            showSuccess("Join request declined")
            return response
        } catch {
            showError(error, title: "Failed to Decline Request", style: .toast)
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
    
    /// Create announcement (ADMIN/MOD only)
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
    
    
    /// Create event (ADMIN/MOD only)
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
                accuracyRate: nil,
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
    // MARK: - Guild Admin Panel (REAL API)
    // ================================================================================================

    // MARK: Guild Settings

    /// Update guild settings (name, description, is_open)
    func updateGuild(name: String?, description: String?, isOpen: Bool?) async throws -> RLGuildDTO {
        guard let guild = currentGuild else { throw NSError(domain: "RLAppState", code: 0, userInfo: [NSLocalizedDescriptionKey: "No guild selected"]) }
        do {
            let updated = try await realApi.updateGuild(guildId: guild.id, name: name, description: description, isOpen: isOpen)
            // Update local state
            self.currentGuild = updated
            showSuccess("Guild settings updated!")
            return updated
        } catch {
            showError(error, title: "Failed to Update Guild", style: .toast)
            throw error
        }
    }

    // MARK: Invite Members

    /// Search users for inviting to guild
    func searchUsersForInvite(search: String) async throws -> [RLUserSearchResultDTO] {
        guard let guild = currentGuild else { return [] }
        do {
            let result = try await realApi.searchUsersForInvite(guildId: guild.id, search: search)
            return result.users
        } catch {
            showError(error, title: "Search Failed", style: .toast)
            throw error
        }
    }

    /// Send a guild invite to a user
    func sendGuildInvite(username: String) async throws -> RLGuildInvitationDTO {
        guard let guild = currentGuild else { throw NSError(domain: "RLAppState", code: 0, userInfo: [NSLocalizedDescriptionKey: "No guild selected"]) }
        do {
            let invitation = try await realApi.createGuildInvite(guildId: guild.id, username: username)
            showSuccess("Invite sent!")
            return invitation
        } catch {
            showError(error, title: "Failed to Send Invite", style: .toast)
            throw error
        }
    }

    /// Fetch pending guild invitations
    func fetchGuildInvites() async throws -> [RLGuildInvitationDTO] {
        guard let guild = currentGuild else { return [] }
        do {
            let result = try await realApi.getGuildInvites(guildId: guild.id)
            return result.invitations
        } catch {
            showError(error, title: "Failed to Load Invites", style: .toast)
            throw error
        }
    }

    /// Cancel a pending guild invite
    func cancelGuildInvite(inviteId: UUID) async throws {
        guard let guild = currentGuild else { return }
        do {
            _ = try await realApi.cancelGuildInvite(guildId: guild.id, inviteId: inviteId)
            showSuccess("Invite cancelled")
        } catch {
            showError(error, title: "Failed to Cancel Invite", style: .toast)
            throw error
        }
    }

    /// Accept a guild invite
    func acceptGuildInvite(guildId: UUID, inviteId: UUID) async throws -> RLGuildWithMembership {
        do {
            let result = try await realApi.acceptGuildInvite(guildId: guildId, inviteId: inviteId)
            showSuccess("Joined guild!")
            return result
        } catch {
            showError(error, title: "Failed to Accept Invite", style: .toast)
            throw error
        }
    }

    /// Decline a guild invite
    func declineGuildInvite(guildId: UUID, inviteId: UUID) async throws {
        do {
            _ = try await realApi.declineGuildInvite(guildId: guildId, inviteId: inviteId)
        } catch {
            showError(error, title: "Failed to Decline Invite", style: .toast)
            throw error
        }
    }

    // MARK: Ban & Kick

    /// Ban a member from the guild
    func banMember(userId: UUID, reason: String?) async throws -> RLGuildBanDTO {
        guard let guild = currentGuild else { throw NSError(domain: "RLAppState", code: 0, userInfo: [NSLocalizedDescriptionKey: "No guild selected"]) }
        do {
            let ban = try await realApi.banMember(guildId: guild.id, userId: userId, reason: reason)
            showSuccess("Member banned")
            return ban
        } catch {
            showError(error, title: "Failed to Ban Member", style: .toast)
            throw error
        }
    }

    /// Unban a member
    func unbanMember(banId: UUID) async throws {
        guard let guild = currentGuild else { return }
        do {
            _ = try await realApi.unbanMember(guildId: guild.id, banId: banId)
            showSuccess("Member unbanned")
        } catch {
            showError(error, title: "Failed to Unban Member", style: .toast)
            throw error
        }
    }

    /// Fetch banned users for the guild
    func fetchGuildBans() async throws -> [RLGuildBanDTO] {
        guard let guild = currentGuild else { return [] }
        do {
            let result = try await realApi.getGuildBans(guildId: guild.id)
            return result.bans
        } catch {
            showError(error, title: "Failed to Load Bans", style: .toast)
            throw error
        }
    }

    /// Kick a member from the guild
    func kickMember(userId: UUID) async throws {
        guard let guild = currentGuild else { return }
        do {
            _ = try await realApi.kickMember(guildId: guild.id, userId: userId)
            showSuccess("Member kicked")
        } catch {
            showError(error, title: "Failed to Kick Member", style: .toast)
            throw error
        }
    }

    // MARK: Mute / Suspend

    /// Mute a member
    func muteMember(userId: UUID, durationMinutes: Int, reason: String?) async throws {
        guard let guild = currentGuild else { return }
        do {
            _ = try await realApi.muteMember(guildId: guild.id, userId: userId, durationMinutes: durationMinutes, reason: reason)
            showSuccess("Member muted")
        } catch {
            showError(error, title: "Failed to Mute Member", style: .toast)
            throw error
        }
    }

    /// Unmute a member
    func unmuteMember(userId: UUID) async throws {
        guard let guild = currentGuild else { return }
        do {
            _ = try await realApi.unmuteMember(guildId: guild.id, userId: userId)
            showSuccess("Member unmuted")
        } catch {
            showError(error, title: "Failed to Unmute Member", style: .toast)
            throw error
        }
    }

    /// Suspend a member
    func suspendMember(userId: UUID, durationMinutes: Int, reason: String?) async throws {
        guard let guild = currentGuild else { return }
        do {
            _ = try await realApi.suspendMember(guildId: guild.id, userId: userId, durationMinutes: durationMinutes, reason: reason)
            showSuccess("Member suspended")
        } catch {
            showError(error, title: "Failed to Suspend Member", style: .toast)
            throw error
        }
    }

    /// Unsuspend a member
    func unsuspendMember(userId: UUID) async throws {
        guard let guild = currentGuild else { return }
        do {
            _ = try await realApi.unsuspendMember(guildId: guild.id, userId: userId)
            showSuccess("Member unsuspended")
        } catch {
            showError(error, title: "Failed to Unsuspend Member", style: .toast)
            throw error
        }
    }

    // MARK: Manage Roles

    /// Change a member's role
    func changeMemberRole(userId: UUID, role: String) async throws -> RLGuildMemberRoleResponseDTO {
        guard let guild = currentGuild else { throw NSError(domain: "RLAppState", code: 0, userInfo: [NSLocalizedDescriptionKey: "No guild selected"]) }
        do {
            let result = try await realApi.changeMemberRole(guildId: guild.id, userId: userId, role: role)
            showSuccess("Role updated to \(role)")
            return result
        } catch {
            showError(error, title: "Failed to Change Role", style: .toast)
            throw error
        }
    }


    // MARK: Content Reports

    /// Fetch guild reports
    func fetchGuildReports(status: String? = nil, contentType: String? = nil) async throws -> RLContentReportsListDTO {
        guard let guild = currentGuild else {
            return RLContentReportsListDTO(reports: [], totalCount: 0, pendingCount: 0)
        }
        do {
            return try await realApi.getGuildReports(guildId: guild.id, status: status, contentType: contentType)
        } catch {
            showError(error, title: "Failed to Load Reports", style: .toast)
            throw error
        }
    }

    /// Resolve or dismiss a report
    func resolveReport(reportId: UUID, action: String, note: String?) async throws -> RLContentReportDTO {
        guard let guild = currentGuild else {
            throw NSError(domain: "RLAppState", code: 0, userInfo: [NSLocalizedDescriptionKey: "No guild selected"])
        }
        do {
            let result = try await realApi.resolveReport(guildId: guild.id, reportId: reportId, action: action, note: note)
            showSuccess("Report \(action)")
            return result
        } catch {
            showError(error, title: "Failed to Resolve Report", style: .toast)
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

    /// Backwards-compatible alias for settings subviews
    func fetchExtendedProfile() async throws -> RLUserProfileDTO {
        return try await fetchCurrentUserExtendedProfile()
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

    /// Backwards-compatible alias for settings subviews
    func updateUserProfile(_ updateRequest: RLUserProfileUpdateRequest) async throws -> RLUserProfileDTO {
        return try await updateCurrentUserProfile(updateRequest)
    }

    /// Update basic user info (display name/username)
    func updateBasicUserInfo(displayName: String?, username: String?) async throws -> RLUserDTO {
        do {
            let request = RLBasicUserUpdateRequest(displayName: displayName, username: username)
            let updated = try await realApi.updateBasicUserInfo(request)
            currentUser = updated
            showSuccess("Profile updated")
            return updated
        } catch {
            showError(error, title: "Failed to Update Profile", style: .toast)
            throw error
        }
    }

    /// Upload avatar image
    func uploadAvatar(imageData: Data, mimeType: String = "image/jpeg") async throws -> RLAvatarUpdateResponse {
        do {
            let response = try await realApi.uploadAvatar(imageData: imageData, mimeType: mimeType)
            if let updatedUser = try? await realApi.getCurrentUser() {
                currentUser = updatedUser
            }
            showSuccess("Avatar updated")
            return response
        } catch {
            showError(error, title: "Failed to Upload Avatar", style: .toast)
            throw error
        }
    }

    /// Remove avatar (revert to default)
    func removeAvatar() async throws -> RLDetailResponseDTO {
        do {
            let response = try await realApi.removeAvatar()
            if let updatedUser = try? await realApi.getCurrentUser() {
                currentUser = updatedUser
            }
            showSuccess("Avatar removed")
            return response
        } catch {
            showError(error, title: "Failed to Remove Avatar", style: .toast)
            throw error
        }
    }

    /// Update trading interests using the extended profile endpoint
    func updateTradingInterests(_ interests: [RLTradingInterestItem]) async throws -> RLUserProfileDTO {
        let request = RLUserProfileUpdateRequest(tradingInterests: interests)
        return try await updateUserProfile(request)
    }

    /// Fetch current user's settings
    func fetchUserSettings() async throws -> RLUserSettingsDTO {
        do {
            let response = try await realApi.getUserSettings()
            userSettings = response
            return response
        } catch {
            showError(error, title: "Failed to Load Settings", style: .toast)
            throw error
        }
    }

    /// Update current user's settings
    func updateUserSettings(_ updateRequest: RLUserSettingsUpdateRequest) async throws -> RLUserSettingsDTO {
        do {
            let response = try await realApi.updateUserSettings(updateRequest)
            userSettings = response
            return response
        } catch {
            showError(error, title: "Failed to Update Settings", style: .toast)
            throw error
        }
    }
    
    /// Fetch current user's global statistics
    func fetchCurrentUserStatistics() async throws -> RLUserGlobalStatisticsDTO {
        do {
            return try await realApi.getCurrentUserStatistics()
        } catch {
            if Task.isCancelled || error is CancellationError {
                throw error
            }
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw error
            }
            if case let APIError.networkError(message) = error,
               message.lowercased().contains("cancelled") {
                throw error
            }
            showError(error, title: "Failed to Load Statistics", style: .toast)
            throw error
        }
    }

    // =============================================================================================
    // MARK: - Account Management (Settings)
    // =============================================================================================

    /// Request password reset email (email or username identifier).
    func requestPasswordReset(identifier: String) async throws -> RLPasswordForgotResponseDTO {
        do {
            return try await realApi.requestPasswordReset(identifier: identifier)
        } catch {
            showError(error, title: "Password Reset Failed", style: .alert)
            throw error
        }
    }

    /// Verify reset token before showing reset form.
    func verifyPasswordResetToken(_ token: String) async throws -> RLPasswordResetVerifyResponseDTO {
        do {
            return try await realApi.verifyPasswordResetToken(token)
        } catch {
            showError(error, title: "Invalid Reset Link", style: .alert)
            throw error
        }
    }

    /// Reset password with one-time token.
    func resetPassword(token: String, newPassword: String) async throws -> RLPasswordResetResponseDTO {
        do {
            return try await realApi.resetPassword(token: token, newPassword: newPassword)
        } catch {
            showError(error, title: "Reset Password Failed", style: .alert)
            throw error
        }
    }

    /// Request email change (sends verification to new email)
    func requestEmailChange(newEmail: String, currentPassword: String) async throws -> RLDetailResponseDTO {
        do {
            let request = RLEmailChangeRequest(newEmail: newEmail, currentPassword: currentPassword)
            let response = try await realApi.requestEmailChange(request)
            showSuccess("Verification email sent")
            return response
        } catch {
            showError(error, title: "Failed to Change Email", style: .toast)
            throw error
        }
    }

    /// Change password
    func changePassword(currentPassword: String, newPassword: String) async throws -> RLDetailResponseDTO {
        do {
            let request = RLPasswordChangeRequest(currentPassword: currentPassword, newPassword: newPassword)
            let response = try await realApi.changePassword(request)
            showSuccess("Password updated")
            return response
        } catch {
            showError(error, title: "Failed to Change Password", style: .toast)
            throw error
        }
    }

    /// Update date of birth
    func updateDateOfBirth(_ date: Date) async throws -> RLDetailResponseDTO {
        do {
            let request = RLDOBUpdateRequest(dateOfBirth: date)
            let response = try await realApi.updateDateOfBirth(request)
            // Refresh user to keep local state in sync
            if let updatedUser = try? await realApi.getCurrentUser() {
                currentUser = updatedUser
            }
            showSuccess("Date of birth updated")
            return response
        } catch {
            showError(error, title: "Failed to Update Date of Birth", style: .toast)
            throw error
        }
    }

    /// Fetch blocked users list
    func fetchBlockedUsers(guildId: UUID? = nil) async throws -> RLBlockedUsersListDTO {
        do {
            return try await realApi.getBlockedUsers(guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Blocked Users", style: .toast)
            throw error
        }
    }

    /// Request a data export for the current user
    func requestDataExportForUser() async throws -> RLDetailResponseDTO {
        do {
            let response = try await realApi.requestDataExport()
            showSuccess("Data export requested")
            return response
        } catch {
            showError(error, title: "Failed to Request Data Export", style: .toast)
            throw error
        }
    }

    /// Submit a support ticket
    func submitSupportTicket(
        category: String,
        subject: String,
        message: String,
        includeDeviceInfo: Bool
    ) async throws -> RLDetailResponseDTO {
        do {
            let request = RLSupportTicketRequest(
                category: category,
                subject: subject,
                message: message,
                includeDeviceInfo: includeDeviceInfo,
                deviceInfo: includeDeviceInfo ? buildDeviceInfo() : nil
            )
            let response = try await realApi.submitSupportTicket(request)
            showSuccess("Support ticket submitted")
            return response
        } catch {
            showError(error, title: "Failed to Send Support Ticket", style: .toast)
            throw error
        }
    }

    /// Delete account permanently
    func deleteAccount(password: String, confirmation: String) async throws {
        do {
            let request = RLDeleteAccountRequest(password: password, confirmation: confirmation)
            _ = try await realApi.deleteAccount(request)
            logout()
        } catch {
            showError(error, title: "Failed to Delete Account", style: .alert)
            throw error
        }
    }

    private func buildDeviceInfo() -> [String: String] {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return [
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "appVersion": appVersion,
            "buildNumber": buildNumber
        ]
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
            if userSettings?.allowFriendRequests == false {
                showError(title: "Action Not Allowed", message: "Friend requests are disabled in your settings", style: .toast)
                throw APIError.badRequest("Friend requests are disabled in your settings")
            }
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
    
    
    
    
    // =============================================================================================
    // MARK: - Combined Data (Drawer Preload) - MESSAGING
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
    // MARK: - CHATROOM MANAGEMENT
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
    func sendChatroomMessage(chatroomId: UUID, content: String, attachmentUrl: String? = nil, attachmentType: String? = nil, attachmentName: String? = nil) async throws -> RLChatroomMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.sendChatroomMessage(
                guildId: guild.id,
                chatroomId: chatroomId,
                content: content,
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName
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
    // MARK: - DIRECT MESSAGES
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
    func sendDMMessage(threadId: UUID, content: String, attachmentUrl: String? = nil, attachmentType: String? = nil, attachmentName: String? = nil) async throws -> RLDMMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.sendDMMessage(
                guildId: guild.id,
                threadId: threadId,
                content: content,
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName
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
    
    
    
    
    
    
    
    
    // =============================================================================================
    // MARK: - WEBSOCKET MANAGEMENT
    // =============================================================================================
    
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
                guard self.shouldShowPresence else { return }
                
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
                guard self.shouldShowPresence else { return }
                let channel = MessagingChannel.guildPresence(guildId).name
                self.currentPresenceChannel = channel
                
                print("👀 [AppState] Subscribing to presence: \(channel)")
                RealTimeService.shared.subscribe(to: [channel], owner: "presence")
            }
            .store(in: &cancellables)

        // 3. React to user presence setting changes
        $userSettings
            .sink { [weak self] settings in
                guard let self = self else { return }
                let shouldShowPresence = settings?.showOnlineStatus ?? true

                if !shouldShowPresence {
                    if let existing = self.currentPresenceChannel {
                        RealTimeService.shared.unsubscribe(from: [existing], owner: "presence")
                        self.currentPresenceChannel = nil
                    }
                    self.presenceByUserId.removeAll()
                    return
                }

                if self.currentPresenceChannel == nil, let guildId = self.currentGuild?.id {
                    let channel = MessagingChannel.guildPresence(guildId).name
                    self.currentPresenceChannel = channel
                    print("👀 [AppState] Subscribing to presence: \(channel)")
                    RealTimeService.shared.subscribe(to: [channel], owner: "presence")
                }
            }
            .store(in: &cancellables)
    }

    // =============================================================================================
    // MARK: - GUILD EVENT LISTENERS (Real-Time Sync)
    // =============================================================================================

    /// Listen for guild_updated and member_role_changed WebSocket events
    /// to keep all clients in sync when an admin makes changes.
    func setupGuildEventListeners() {
        RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self = self else { return }
                guard let type = WSMessageType(rawValue: message.type) else { return }

                switch type {
                case .guildUpdated:
                    self.handleGuildUpdatedEvent(message)
                case .memberRoleChanged:
                    self.handleMemberRoleChangedEvent(message)
                case .memberMuted:
                    self.handleMemberMutedEvent(message)
                case .memberSuspended:
                    self.handleMemberSuspendedEvent(message)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func handleGuildUpdatedEvent(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: WSGuildUpdatedPayload.self) else { return }
        guard let guildId = UUID(uuidString: payload.guildId) else { return }

        // Update currentGuild if it matches
        if let current = currentGuild, current.id == guildId {
            currentGuild = current.withUpdatedSettings(
                name: payload.name,
                description: payload.description,
                isOpen: payload.isOpen
            )
            print("🏰 [AppState] Guild settings updated via WebSocket: \(payload.name ?? "nil")")
        }
    }

    private func handleMemberRoleChangedEvent(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: WSMemberRoleChangedPayload.self) else { return }
        guard let userId = UUID(uuidString: payload.userId),
              let guildId = UUID(uuidString: payload.guildId) else { return }

        // If the role change affects the current user's own membership, update it
        if userId == currentUser?.id, let membership = currentMembership, membership.guildId == guildId {
            currentMembership = membership.withRole(payload.newRole)
            print("🏰 [AppState] Own role updated via WebSocket: \(payload.oldRole) → \(payload.newRole)")
        }

        // Post a notification so any open member lists/profiles can refresh
        NotificationCenter.default.post(
            name: .guildMemberRoleChanged,
            object: nil,
            userInfo: [
                "guildId": guildId,
                "userId": userId,
                "oldRole": payload.oldRole,
                "newRole": payload.newRole
            ]
        )
        print("🏰 [AppState] Member role changed via WebSocket: user=\(payload.userId) \(payload.oldRole)→\(payload.newRole)")
    }

    private func handleMemberMutedEvent(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: WSMemberMutedPayload.self) else { return }
        guard let userId = UUID(uuidString: payload.userId),
              let guildId = UUID(uuidString: payload.guildId) else { return }

        // Post notification so member lists can update
        NotificationCenter.default.post(
            name: .guildMemberMuteChanged,
            object: nil,
            userInfo: [
                "guildId": guildId,
                "userId": userId,
                "mutedUntil": payload.mutedUntil as Any,
                "action": payload.action
            ]
        )
        print("🔇 [AppState] Member mute event via WebSocket: user=\(payload.userId) action=\(payload.action)")
    }

    private func handleMemberSuspendedEvent(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: WSMemberSuspendedPayload.self) else { return }
        guard let userId = UUID(uuidString: payload.userId),
              let guildId = UUID(uuidString: payload.guildId) else { return }

        // Post notification so member lists can update
        NotificationCenter.default.post(
            name: .guildMemberSuspendChanged,
            object: nil,
            userInfo: [
                "guildId": guildId,
                "userId": userId,
                "suspendedUntil": payload.suspendedUntil as Any,
                "action": payload.action
            ]
        )
        print("⏸️ [AppState] Member suspend event via WebSocket: user=\(payload.userId) action=\(payload.action)")
    }

    // =============================================================================================
    // MARK: - NOTIFICATION MANAGEMENT
    // =============================================================================================

    /// Fetch paginated notifications
    func fetchNotifications(
        types: [String]? = nil,
        isRead: Bool? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> RLNotificationListDTO {
        do {
            return try await realApi.getNotifications(
                types: types,
                isRead: isRead,
                page: page,
                pageSize: pageSize
            )
        } catch {
            showError(error, title: "Failed to Load Notifications", style: .toast)
            throw error
        }
    }

    /// Fetch notification badge counts
    func fetchNotificationStats() async throws -> RLNotificationStatsDTO {
        do {
            let stats = try await realApi.getNotificationStats()
            self.notificationStats = stats
            return stats
        } catch {
            showError(error, title: "Failed to Load Notification Stats", style: .toast)
            throw error
        }
    }

    /// Mark specific notifications as read
    func markNotificationsAsRead(ids: [UUID]) async {
        do {
            try await realApi.markNotificationsAsRead(ids: ids)
        } catch {
            print("⚠️ Failed to mark notifications as read: \(error)")
        }
    }

    /// Mark all notifications as read
    func markAllNotificationsAsRead() async {
        do {
            try await realApi.markAllNotificationsAsRead()
            // Refresh stats to update badge
            _ = try? await fetchNotificationStats()
        } catch {
            showError(error, title: "Failed to Mark All as Read", style: .toast)
        }
    }

    /// Record a notification view (analytics)
    func recordNotificationView(notificationId: UUID) async throws {
        try await realApi.recordNotificationView(notificationId: notificationId)
    }


    // MARK: - WebSocket Notification Subscription

    /// Call this when user logs in / connects WebSocket.
    /// The realtime-service auto-subscribes the user to their notification channel,
    /// so this is just for subscribing on the iOS side to the existing WS connection.
    func subscribeToNotifications() {
        guard let userId = currentUser?.id else { return }
        let channel = "user:\(userId):notifications"
        RealTimeService.shared.subscribe(to: [channel], owner: "notifications")
    }

    /// Unsubscribe when logging out
    func unsubscribeFromNotifications() {
        guard let userId = currentUser?.id else { return }
        let channel = "user:\(userId):notifications"
        RealTimeService.shared.unsubscribe(from: [channel], owner: "notifications")
    }
    
    // =============================================================================================
    // MARK: - Chart Management (REAL API)
    // =============================================================================================
    
    /// Fetch user's personal watchlist
    func fetchPersonalWatchlist() async throws -> RLPersonalWatchlistDTO {
        do {
            return try await realApi.getPersonalWatchlist()
        } catch {
            showError(error, title: "Failed to Load Watchlist", style: .toast)
            throw error
        }
    }
    
    /// Fetch guild's watchlist
    func fetchGuildWatchlist(guildId: UUID) async throws -> RLGuildWatchlistDTO {
        do {
            return try await realApi.getGuildWatchlist(guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Watchlist", style: .toast)
            throw error
        }
    }

    /// Add symbol to guild watchlist (admin/owner)
    func addToGuildWatchlist(guildId: UUID, symbolId: UUID) async throws -> RLWatchlistSymbolDTO {
        do {
            let result = try await realApi.addToGuildWatchlist(guildId: guildId, symbolId: symbolId)
            showSuccess("Added to guild watchlist")
            return result
        } catch {
            showError(error, title: "Failed to Add Symbol", style: .toast)
            throw error
        }
    }

    /// Remove symbol from guild watchlist (admin/owner)
    func removeFromGuildWatchlist(guildId: UUID, symbolId: UUID) async throws {
        do {
            _ = try await realApi.removeFromGuildWatchlist(guildId: guildId, symbolId: symbolId)
            showSuccess("Removed from guild watchlist")
        } catch {
            showError(error, title: "Failed to Remove Symbol", style: .toast)
            throw error
        }
    }
    
    /// Add symbol to personal watchlist
    func addToPersonalWatchlist(symbolId: UUID) async throws -> RLWatchlistSymbolDTO {
        do {
            let result = try await realApi.addToPersonalWatchlist(symbolId: symbolId)
            showSuccess("Added to watchlist")
            return result
        } catch {
            showError(error, title: "Failed to Add Symbol", style: .toast)
            throw error
        }
    }
    
    /// Remove symbol from personal watchlist
    func removeFromPersonalWatchlist(symbolId: UUID) async throws {
        do {
            _ = try await realApi.removeFromPersonalWatchlist(symbolId: symbolId)
            showSuccess("Removed from watchlist")
        } catch {
            showError(error, title: "Failed to Remove Symbol", style: .toast)
            throw error
        }
    }
    
    /// Reorder personal watchlist
    func reorderPersonalWatchlist(symbolIds: [UUID]) async throws {
        do {
            _ = try await realApi.reorderPersonalWatchlist(symbolIds: symbolIds)
        } catch {
            showError(error, title: "Failed to Reorder Watchlist", style: .toast)
            throw error
        }
    }

    /// Request a guild watchlist addition
    func requestGuildWatchlistAddition(guildId: UUID, symbolId: UUID) async throws {
        do {
            _ = try await realApi.requestGuildWatchlistAddition(guildId: guildId, symbolId: symbolId)
            showSuccess("Request submitted")
        } catch {
            showError(error, title: "Failed to Request Watchlist Add", style: .toast)
            throw error
        }
    }

    /// Fetch guild watchlist requests
    func fetchGuildWatchlistRequests(status: String = "pending") async throws -> RLGuildWatchlistRequestsListResponseDTO {
        guard let guildId = currentGuild?.id else {
            return RLGuildWatchlistRequestsListResponseDTO(requests: [], totalCount: 0)
        }
        do {
            return try await realApi.getGuildWatchlistRequests(guildId: guildId, status: status)
        } catch {
            showError(error, title: "Failed to Load Requests", style: .toast)
            throw error
        }
    }

    /// Approve or reject a guild watchlist request
    func reviewGuildWatchlistRequest(
        requestId: UUID,
        action: String,
        reviewNote: String? = nil
    ) async throws -> RLGuildWatchlistRequestResponseDTO {
        guard let guildId = currentGuild?.id else {
            throw RLAppError.noGuildSelected
        }
        do {
            let response = try await realApi.reviewGuildWatchlistRequest(
                guildId: guildId,
                requestId: requestId,
                action: action,
                reviewNote: reviewNote
            )
            showSuccess(action == "approved" ? "Request approved" : "Request rejected")
            return response
        } catch {
            showError(error, title: "Failed to Review Request", style: .toast)
            throw error
        }
    }
    
    /// Fetch combined chart data (symbol + candles + markers)
    func fetchChartData(guildId: UUID, symbolId: UUID, timeframe: String, candleLimit: Int = 200) async throws -> RLChartDataDTO {
        do {
            return try await realApi.getChartData(
                guildId: guildId,
                symbolId: symbolId,
                timeframe: timeframe,
                candleLimit: candleLimit
            )
        } catch {
            showError(error, title: "Failed to Load Chart Data", style: .toast)
            throw error
        }
    }
    
    /// Get or create a chart chat for a symbol + guild
    func getOrCreateChartChat(guildId: UUID, symbolId: UUID) async throws -> RLChartChatDTO {
        do {
            return try await realApi.getOrCreateChartChat(guildId: guildId, symbolId: symbolId)
        } catch {
            showError(error, title: "Failed to Open Chat", style: .toast)
            throw error
        }
    }
    
    /// Send a message to a chart chat
    func sendChartChatMessage(chatId: UUID, content: String) async throws -> RLChartChatMessageDTO {
        do {
            return try await realApi.sendChartChatMessage(chatId: chatId, content: content)
        } catch {
            showError(error, title: "Failed to Send Message", style: .toast)
            throw error
        }
    }

    // =============================================================================================
    // MARK: - Reporting & Sharing (Pending backend support)
    // =============================================================================================

    func reportChatroom(guildId: UUID, chatroomId: UUID, reason: String) async throws {
        do {
            _ = try await realApi.reportChatroom(guildId: guildId, chatroomId: chatroomId, reason: reason)
            showSuccess("Report submitted")
        } catch {
            showError(error, title: "Failed to Report Chatroom", style: .toast)
            throw error
        }
    }

    func reportUser(guildId: UUID, userId: UUID, reason: String) async throws {
        do {
            _ = try await realApi.reportUser(guildId: guildId, userId: userId, reason: reason)
            showSuccess("Report submitted")
        } catch {
            showError(error, title: "Failed to Report User", style: .toast)
            throw error
        }
    }

    func shareEvent(guildId: UUID, eventId: UUID, friendId: UUID) async throws {
        do {
            _ = try await realApi.shareEvent(guildId: guildId, eventId: eventId, friendId: friendId)
            showSuccess("Event shared")
        } catch {
            showError(error, title: "Failed to Share Event", style: .toast)
            throw error
        }
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

// MARK: - Notification Names for Guild Events

extension Notification.Name {
    /// Posted when a member's role changes via WebSocket.
    /// userInfo: ["guildId": UUID, "userId": UUID, "oldRole": String, "newRole": String]
    static let guildMemberRoleChanged = Notification.Name("guildMemberRoleChanged")

    /// Posted when a member's mute status changes via WebSocket.
    /// userInfo: ["guildId": UUID, "userId": UUID, "mutedUntil": String?, "action": String]
    static let guildMemberMuteChanged = Notification.Name("guildMemberMuteChanged")

    /// Posted when a member's suspend status changes via WebSocket.
    /// userInfo: ["guildId": UUID, "userId": UUID, "suspendedUntil": String?, "action": String]
    static let guildMemberSuspendChanged = Notification.Name("guildMemberSuspendChanged")

    /// Posted when a user's reputation changes via WebSocket.
    /// userInfo: ["guildId": String, "newGuildReputation": Int, "newGlobalReputation": Int, "tierLevel": Int, "tierChanged": Bool, "pointsAwarded": Int]
    static let reputationDidUpdate = Notification.Name("reputationDidUpdate")

    /// Posted when a user's trading accuracy changes via WebSocket (prediction win/loss).
    /// userInfo: ["guildId": String, "newAccuracyRate": Double, "totalPredictions": Int, "successfulPredictions": Int, "winStreak": Int, "isWin": Bool]
    static let accuracyDidUpdate = Notification.Name("accuracyDidUpdate")

    /// Posted when a marker share card is tapped inside chat.
    /// userInfo: ["markerId": String, "symbolId": String, "timeframe": String, "candleTimestamp": Date, "symbolTicker": String?]
    static let openSharedMarker = Notification.Name("openSharedMarker")

    /// Posted after chart symbol/timeframe has been prepared for a shared marker.
    /// userInfo mirrors openSharedMarker payload.
    static let focusSharedMarker = Notification.Name("focusSharedMarker")
}
