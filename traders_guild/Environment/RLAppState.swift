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
import Network

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
                currentGlobalAccuracy = nil
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

    /// Live global accuracy for the current user, sourced from reputation-service.
    @Published var currentGlobalAccuracy: Double?

    /// Public accessor for refresh token (used by biometric enrollment)
    var currentRefreshToken: String? { refreshToken }

    /// Whether to show biometric enrollment sheet after login
    @Published var showBiometricEnrollment: Bool = false

    /// Pre-filled signup data from Apple Sign In for new Apple users entering onboarding.
    /// Set by loginWithApple() when the backend reports a new user; consumed by ContentView
    /// to route into the Apple onboarding path.
    @Published var appleSignUpPrefill: RLSignupData?

    /// Tracks onboarding progress so users can resume from the correct step.
    /// Persisted to UserDefaults and cleared on logout or onboarding completion.
    @Published var onboardingState: RLOnboardingState? {
        didSet { saveOnboardingState(onboardingState) }
    }

    /// True once the user's account record has been created (email signup or Apple).
    /// Used to disable backward navigation in the onboarding flow.
    @Published var accountCreatedDuringOnboarding: Bool = false

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

    /// Current user as a GuildMemberDTO — useful for creating optimistic/pending messages.
    var currentGuildMember: RLGuildMemberDTO? {
        guard let user = currentUser, let membership = currentMembership else { return nil }
        return RLGuildMemberDTO(
            membershipId: membership.id,
            role: membership.role,
            reputation: membership.reputation,
            contributionScore: membership.contributionScore,
            dateJoined: membership.dateJoined,
            accuracyRate: membership.accuracyRate,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            isOnline: true,
            globalReputation: user.globalReputation,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
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
    private var isConsumingPendingEmailVerificationToken: Bool = false
    
    @Published var showGuildSelectionSheet: Bool = false
    @Published var showBetaWelcomeSheet: Bool = false
    @Published var showSignupWelcomeCarousel: Bool = false
    @Published var isBiometricAppLockActive: Bool = false
    @Published var isBiometricUnlockInProgress: Bool = false
    @Published var biometricUnlockErrorMessage: String?
    @Published private(set) var biometricUnlockRequestID: UUID?
    @Published private(set) var runtimeFlags: RLRuntimeFlagsDTO = .disabled
    @Published private(set) var reportedUserStateVersion: Int = 0

    /// Keeps auth/signup onboarding in ContentView even after auth tokens are issued.
    @Published var isOnboardingFlowActive: Bool = false

    /// Password reset token captured from deep-link.
    @Published var pendingPasswordResetToken: String?
    @Published var pendingEmailVerificationToken: String?
    
    /// Flag to prevent race conditions during login/signup flow
    /// When true, external triggers (like onAppear) should NOT call openGuildSelector
    @Published var isHandlingAuthFlow: Bool = false
    
    /// Available guilds for selection (combined view model)
    @Published var userGuilds: [RLGuildWithMembership] = []

    var shouldPresentBiometricAppLock: Bool {
        shouldUseBiometricAppLock && isBiometricAppLockActive
    }

    private var shouldUseBiometricAppLock: Bool {
        isAuthenticated && !isOnboardingFlowActive && BiometricAuthManager.shared.canUseBiometricLogin
    }
    private var shouldTriggerBiometricUnlockOnNextActive = false
    
    // ================================================================================================
    // MARK: - Services
    // ================================================================================================
    
    let realApi = RealAPIService()
    private var cancellables = Set<AnyCancellable>()
    @Published var presenceByUserId: [UUID: Bool] = [:]
    private var currentPresenceChannel: String?
    private let reachabilityMonitor = NWPathMonitor()
    private let reachabilityQueue = DispatchQueue(label: "traders_guild.reachability")
    private var lastReachabilitySatisfied: Bool?
    private var hasShownOfflineToastForCurrentEpisode = false
    private var pendingSignupWelcomeUserId: UUID?
    private let reportedUserStore = ReportedUserStore()

    @Published var notificationStats: RLNotificationStatsDTO? {
        didSet {
            syncNotificationBadge()
        }
    }
    
    // ================================================================================================
    // MARK: - Initialization
    // ================================================================================================
    
    init() {
        print("🌐 App environment: mode=\(AppConfig.apiRoutingMode.rawValue) sessionNamespace=\(AppConfig.sessionStorageNamespace)")

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
        startReachabilityMonitor()
        
        Task {
            await restoreSession()
        }
    }

    deinit {
        reachabilityMonitor.cancel()
    }
    
    /// Handle authentication failure (refresh token expired)
    /// Called automatically by RealAPIService when token refresh fails
    private func handleAuthenticationFailure() {
        print("🔐 Authentication failure - session expired, logging out...")

        let hadVisibleSession =
            isAuthenticated
            || currentUser != nil
            || currentGuild != nil
            || currentMembership != nil
            || hasCompletedInitialLoad
        let isInteractiveAuthFlow =
            isHandlingAuthFlow
            || isOnboardingFlowActive
            || pendingPasswordResetToken != nil

        clearLocalSessionState(clearAlertState: true)

        guard hadVisibleSession && !isInteractiveAuthFlow else {
            return
        }

        showError(
            title: "Session Expired",
            message: "Please log in again",
            severity: .warning,
            style: .alert
        )
    }

    private func startReachabilityMonitor() {
        reachabilityMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleReachabilityTransition(isSatisfied: path.status == .satisfied)
            }
        }
        reachabilityMonitor.start(queue: reachabilityQueue)
    }

    private func handleReachabilityTransition(isSatisfied: Bool) {
        let previous = lastReachabilitySatisfied
        lastReachabilitySatisfied = isSatisfied

        if isSatisfied {
            hasShownOfflineToastForCurrentEpisode = false
            return
        }

        guard previous == true else { return }
        guard isAuthenticated, currentUser != nil else { return }
        guard !hasShownOfflineToastForCurrentEpisode else { return }

        hasShownOfflineToastForCurrentEpisode = true
        showInfo(
            "Connection lost. We’ll reconnect when you’re back online.",
            title: "Offline"
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
        presentPendingSignupWelcomeIfNeeded()
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

        let mappedMessage = RLUserFacingErrorMapper.message(from: error)
        let resolvedTitle = title == "Error" ? RLUserFacingCopy.text(.errorTitle) : title
        let alert = RLAppAlert(
            title: resolvedTitle,
            message: mappedMessage,
            severity: .error,
            style: style
        )
        currentAlert = alert
        if style == .toast {
            ToastWindowManager.shared.showToast(alert) { [weak self] in self?.clearAlert() }
        }
    }

    func userSafeMessage(for error: Error) -> String {
        RLUserFacingErrorMapper.message(from: error)
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
    
    func showSuccess(_ message: String, title: String = RLUserFacingCopy.text(.successTitle)) {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: .success,
            style: .toast
        )
        currentAlert = alert
        ToastWindowManager.shared.showToast(alert) { [weak self] in self?.clearAlert() }
    }
    
    func showInfo(_ message: String, title: String = RLUserFacingCopy.text(.infoTitle)) {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: .info,
            style: .toast
        )
        currentAlert = alert
        ToastWindowManager.shared.showToast(alert) { [weak self] in self?.clearAlert() }
    }
    
    func showWarning(_ message: String, title: String = RLUserFacingCopy.text(.warningTitle)) {
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

    private func syncNotificationBadge() {
        UIApplication.shared.applicationIconBadgeNumber = max(notificationStats?.unreadCount ?? 0, 0)
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
            
            accountCreatedDuringOnboarding = beginOnboarding
            onboardingState = beginOnboarding ? .accountCreated : nil

            if !beginOnboarding {
                showSuccess(RLUserFacingCopy.format(.successWelcomeUser, response.user.username))
            }
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
        clearAlert()
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
            
            // Check if returning user has incomplete onboarding
            let storedState = getOnboardingStateFromKeychain()
            let hasIncompleteOnboarding = storedState != nil && storedState != .complete
            let usernameMissing = response.user.username.isEmpty
                || response.user.username.hasPrefix("apple_user_")
                || response.user.username.hasPrefix("user_")

            if hasIncompleteOnboarding || usernameMissing {
                onboardingState = storedState ?? .accountCreated
                accountCreatedDuringOnboarding = true
                isOnboardingFlowActive = true
                isHandlingAuthFlow = false
            } else {
                try await completePostAuthGuildSetup(context: "Login")
                clearBiometricAppLock()
                subscribeToNotifications(reason: .login)
                
                print("🔐 Login: Final state - currentGuild: \(currentGuild?.name ?? "nil"), showSheet: \(showGuildSelectionSheet)")
                
                isOnboardingFlowActive = false
            }

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

    /// Login or register via Apple Sign In.
    /// Routes new Apple users into onboarding; returning users straight to guild setup.
    func loginWithApple(identityToken: String, authorizationCode: String, fullName: String?, email: String?) async throws {
        isLoading = true
        isHandlingAuthFlow = true
        isCompletingSignup = true
        defer {
            isLoading = false
            isCompletingSignup = false
        }

        do {
            let response = try await realApi.loginWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName,
                email: email
            )

            self.accessToken = response.tokens.accessToken
            self.refreshToken = response.tokens.refreshToken
            self.currentUser = response.user
            self.currentGuild = nil
            self.currentMembership = nil
            self.isSessionRestored = true

            // Determine if this is a new user who needs onboarding.
            // Use backend flag when available; fall back to heuristic (empty/placeholder username).
            let userNeedsOnboarding: Bool = {
                if let explicit = response.isNewUser { return explicit }
                if let state = response.onboardingState, state == "onboarding_complete" { return false }
                let username = response.user.username
                return username.isEmpty
                    || username.hasPrefix("apple_user_")
                    || username.hasPrefix("user_")
            }()

            if userNeedsOnboarding {
                var prefill = RLSignupData()
                prefill.isAppleSignUp = true
                prefill.name = RLAuthValidator.normalizedAppleDisplayName(fullName)
                prefill.email = email ?? response.user.email
                self.appleSignUpPrefill = prefill

                accountCreatedDuringOnboarding = true
                onboardingState = .accountCreated
                isOnboardingFlowActive = true
                isHandlingAuthFlow = false
            } else {
                // Returning Apple user -- normal post-auth flow
                try await fetchUserGuilds()
                try await completePostAuthGuildSetup(context: "Apple Sign In")
                clearBiometricAppLock()
                subscribeToNotifications(reason: .login)
                isOnboardingFlowActive = false
            }

        } catch {
            isHandlingAuthFlow = false
            showError(error, title: "Apple Sign In Failed", style: .alert)
            throw error
        }
    }

    /// Sync onboarding data to backend for Apple Sign In users.
    /// Called before guild selection since the Apple account was created with placeholder data.
    /// Only sends fields not covered by SignupProfileSetupView (which sends interests, language, etc.).
    func syncAppleOnboardingData(_ data: RLSignupData) async throws {
        let updatedUser = try await realApi.updateBasicUserInfo(
            RLBasicUserUpdateRequest(
                displayName: data.name.isEmpty ? nil : data.name,
                username: data.username.isEmpty ? nil : data.username
            )
        )
        self.currentUser = updatedUser

        if let dob = data.dateOfBirth {
            _ = try await realApi.updateDateOfBirth(RLDOBUpdateRequest(dateOfBirth: dob))
        }
    }

    /// Verify email address with token
    @discardableResult
    func verifyEmail(token: String) async throws -> RLEmailVerifyResponseDTO {
        let response = try await realApi.verifyEmail(token: token)
        if response.verified {
            if accessToken != nil, let refreshedUser = try? await realApi.getCurrentUser() {
                currentUser = refreshedUser
            } else {
                markCurrentUserVerifiedLocally()
            }
        }
        return response
    }

    /// Resend email verification link
    func resendVerificationEmail() async throws -> RLPasswordForgotResponseDTO {
        try await realApi.resendVerificationEmail()
    }

    @discardableResult
    func consumePendingEmailVerificationToken() async -> Bool {
        guard !isConsumingPendingEmailVerificationToken,
              let token = pendingEmailVerificationToken,
              !token.isEmpty else {
            return false
        }

        isConsumingPendingEmailVerificationToken = true
        defer {
            isConsumingPendingEmailVerificationToken = false
            pendingEmailVerificationToken = nil
        }

        do {
            let response = try await verifyEmail(token: token)
            if response.verified {
                let message = response.detail.isEmpty ? "Email verified successfully!" : response.detail
                showSuccess(message)
                return true
            }

            let message = response.detail.isEmpty ? "Invalid or expired verification token." : response.detail
            showError(
                title: "Verification Failed",
                message: message,
                severity: .warning,
                style: .alert
            )
            return false
        } catch {
            showError(error)
            return false
        }
    }

    private func markCurrentUserVerifiedLocally() {
        guard let user = currentUser else { return }
        currentUser = RLUserDTO(
            id: user.id,
            email: user.email,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            globalReputation: user.globalReputation,
            isOnline: user.isOnline,
            isVerified: true,
            isSuperuser: user.isSuperuser,
            lastSeenAt: user.lastSeenAt,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
            dateOfBirth: user.dateOfBirth,
            status: user.status,
            authProvider: user.authProvider
        )
    }

    // MARK: - Biometric Authentication

    /// Offer biometric enrollment if available and not already set up
    func offerBiometricEnrollmentIfNeeded() {
        let manager = BiometricAuthManager.shared
        guard manager.isBiometricAvailable,
              !manager.isBiometricEnabled,
              !UserDefaults.standard.bool(forKey: "traders_guild_biometric_declined") else {
            return
        }
        // Delay so the guild selection sheet fully dismisses before presenting this sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self, !self.showGuildSelectionSheet else { return }
            self.showBiometricEnrollment = true
        }
    }

    /// Attempt to restore session using biometric authentication
    func loginWithBiometric() async throws {
        let manager = BiometricAuthManager.shared
        guard manager.canUseBiometricLogin else {
            throw BiometricAuthManager.BiometricError.notAvailable
        }

        isLoading = true
        isHandlingAuthFlow = true
        defer { isLoading = false }

        do {
            // This triggers FaceID/TouchID and retrieves the token from Keychain
            guard let storedRefreshToken = try await manager.retrieveBiometricRefreshToken() else {
                isHandlingAuthFlow = false
                throw BiometricAuthManager.BiometricError.authenticationFailed
            }

            // Use the refresh token to get new access tokens
            realApi.setTokens(access: "", refresh: storedRefreshToken)
            let refreshed = try await realApi.refreshAccessToken()

            self.accessToken = refreshed.accessToken
            self.refreshToken = refreshed.refreshToken
            self.isSessionRestored = true

            // Restore cached user
            if let user = getUserFromKeychain() {
                self.currentUser = user
            }

            // Fetch guilds
            try await fetchUserGuilds()
            try await completePostAuthGuildSetup(context: "Biometric Login")

            // Update biometric token with the new refresh token
            if let newRefresh = self.refreshToken {
                try? manager.storeBiometricRefreshToken(newRefresh)
            }

            clearBiometricAppLock()
            subscribeToNotifications(reason: .biometricLogin)

        } catch {
            isHandlingAuthFlow = false
            // Clear biometric on persistent failure
            if case BiometricAuthManager.BiometricError.authenticationFailed = error {
                // User cancelled — don't clear
            } else {
                // Token expired or invalid — clear biometric
                manager.disableBiometric()
            }
            throw error
        }
    }

    /// Logout and clear session
    func logout() {
        // Unsubscribe from notifications
        unsubscribeFromNotifications()
        Task {
            await realApi.logout()
        }

        clearLocalSessionState(clearAlertState: true)
        showInfo(RLUserFacingCopy.text(.infoLoggedOut))
    }

    /// Leave signup/onboarding mid-flow: revoke tokens, clear local session, return user to welcome/sign-in.
    func abandonSignupAndReturnToWelcome() {
        unsubscribeFromNotifications()
        Task {
            await realApi.logout()
        }
        clearLocalSessionState(clearAlertState: true)
        showInfo(RLUserFacingCopy.text(.infoSignInAgain))
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

            onboardingState = .complete
            accountCreatedDuringOnboarding = false
            isOnboardingFlowActive = false
            queueSignupWelcomeCarouselIfNeeded()
            showTransitionForChartLoad(minimumDuration: 2.5)

            // Offer biometric enrollment after the chart transition finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                self?.offerBiometricEnrollmentIfNeeded()
            }
        }
    }

    func setPendingPasswordResetToken(_ token: String?) {
        pendingPasswordResetToken = token
    }

    func setPendingEmailVerificationToken(_ token: String?) {
        pendingEmailVerificationToken = token
    }

    func dismissSignupWelcomeCarousel() {
        showSignupWelcomeCarousel = false
    }

    func dismissBetaWelcomeSheet() {
        showBetaWelcomeSheet = false
        presentPendingSignupWelcomeIfNeeded()
    }

    func refreshRuntimeFlags() async {
        guard isAuthenticated, accessToken != nil else {
            runtimeFlags = .disabled
            return
        }

        do {
            runtimeFlags = try await realApi.getRuntimeFlags()
            presentPendingSignupWelcomeIfNeeded()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    func armBiometricAppLockIfNeeded(reason: String, autoPromptWhenActive: Bool = true) {
        guard shouldUseBiometricAppLock else {
            clearBiometricAppLock()
            return
        }

        biometricUnlockErrorMessage = nil
        isBiometricAppLockActive = true
        if autoPromptWhenActive {
            shouldTriggerBiometricUnlockOnNextActive = false
            biometricUnlockRequestID = UUID()
        } else {
            shouldTriggerBiometricUnlockOnNextActive = true
            biometricUnlockRequestID = nil
        }
        print("🔐 App lock armed (\(reason))")
    }

    func clearBiometricAppLock() {
        isBiometricAppLockActive = false
        isBiometricUnlockInProgress = false
        biometricUnlockErrorMessage = nil
        biometricUnlockRequestID = nil
        shouldTriggerBiometricUnlockOnNextActive = false
    }

    func handleSceneDidBecomeActive() {
        guard shouldUseBiometricAppLock else {
            clearBiometricAppLock()
            return
        }
        guard shouldTriggerBiometricUnlockOnNextActive else { return }
        shouldTriggerBiometricUnlockOnNextActive = false
        biometricUnlockRequestID = UUID()
        print("🔐 App lock requested on foreground return")
    }

    func handleSceneDidEnterBackground() {
        guard shouldUseBiometricAppLock else { return }
        armBiometricAppLockIfNeeded(reason: "scene_background", autoPromptWhenActive: false)
    }

    func unlockBiometricAppLock() async {
        guard shouldPresentBiometricAppLock else { return }
        guard !isBiometricUnlockInProgress else { return }

        isBiometricUnlockInProgress = true
        biometricUnlockErrorMessage = nil

        defer {
            isBiometricUnlockInProgress = false
        }

        do {
            let authenticated = try await BiometricAuthManager.shared.authenticate(
                reason: "Unlock Traders Guild"
            )
            guard authenticated else {
                biometricUnlockErrorMessage = "Unable to unlock with biometrics."
                return
            }
            clearBiometricAppLock()
        } catch {
            if case BiometricAuthManager.BiometricError.authenticationFailed = error {
                biometricUnlockErrorMessage = "Unlock cancelled or failed."
            } else {
                biometricUnlockErrorMessage = RLUserFacingErrorMapper.message(from: error)
            }
        }
    }
    
    /// Restore session from keychain
    func restoreSession() async {
        print("🔄 restoreSession: Starting...")
        print("🔄 restoreSession: Using session namespace \(AppConfig.sessionStorageNamespace)")

        // Do not let background restoration clobber an active auth/signup flow.
        if isAuthenticated || isHandlingAuthFlow || isOnboardingFlowActive {
            isSessionRestored = true
            return
        }
        
        // Restore tokens
        let storedAccessToken = getTokenFromKeychain()
        let storedRefreshToken = getRefreshTokenFromKeychain()
        let hasStoredSessionArtifacts = storedAccessToken != nil || storedRefreshToken != nil

        if storedAccessToken != nil {
            print("🔄 restoreSession: Found access token")
        }
        if storedRefreshToken != nil {
            print("🔄 restoreSession: Found refresh token")
        }

        var resolvedAccessToken = storedAccessToken.flatMap { Self.normalizedJWT($0) }
        var resolvedRefreshToken = storedRefreshToken.flatMap { token in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        var shouldClearStoredSession = false

        if storedAccessToken != nil && resolvedAccessToken == nil {
            print("⚠️ restoreSession: Discarding malformed cached access token")
            shouldClearStoredSession = true
        }

        if storedRefreshToken != nil && resolvedRefreshToken == nil {
            print("⚠️ restoreSession: Discarding empty cached refresh token")
            shouldClearStoredSession = true
        }

        // Set tokens on realApi and try to refresh before publishing accessToken
        if let access = resolvedAccessToken, let refresh = resolvedRefreshToken {
            realApi.setTokens(access: access, refresh: refresh)
            print("🔄 restoreSession: Tokens set on API service")
            do {
                let refreshed = try await realApi.refreshAccessToken()
                resolvedAccessToken = refreshed.accessToken
                resolvedRefreshToken = refreshed.refreshToken
                print("🔄 restoreSession: Tokens refreshed")
            } catch {
                print("⚠️ restoreSession: Token refresh failed: \(error)")
                resolvedAccessToken = nil
                resolvedRefreshToken = nil
                shouldClearStoredSession = true
                realApi.clearTokens()
            }
        } else if resolvedAccessToken != nil || resolvedRefreshToken != nil {
            print("⚠️ restoreSession: Incomplete cached token pair, clearing session restore state")
            resolvedAccessToken = nil
            resolvedRefreshToken = nil
            shouldClearStoredSession = true
            realApi.clearTokens()
        }

        // If auth/signup completed while we were restoring, keep live in-memory state.
        if isAuthenticated || isHandlingAuthFlow || isOnboardingFlowActive || currentUser != nil {
            print("🔄 restoreSession: Skipping apply - live auth state already established")
            isSessionRestored = true
            return
        }

        if shouldClearStoredSession && hasStoredSessionArtifacts {
            print("🔄 restoreSession: Clearing invalid cached session artifacts")
            clearLocalSessionState(clearAlertState: true)
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
            // Check for incomplete onboarding before entering normal app flow
            let storedOnboarding = getOnboardingStateFromKeychain()
            if let state = storedOnboarding, state != .complete {
                print("🔄 restoreSession: Incomplete onboarding detected (\(state.rawValue)), resuming")
                onboardingState = state
                accountCreatedDuringOnboarding = true
                isOnboardingFlowActive = true
            } else {
                do {
                    userSettings = try await realApi.getUserSettings()
                } catch {
                    print("⚠️ restoreSession: Failed to fetch user settings: \(error)")
                }
                armBiometricAppLockIfNeeded(reason: "session_restore")
                subscribeToNotifications(reason: .sessionRestore)
            }
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

        // Offer biometric enrollment only when entering the app for the first time in this session
        // (not during guild switching or onboarding -- those paths handle it separately)
        if !isOnboardingFlowActive && !isFinalizingOnboarding {
            offerBiometricEnrollmentIfNeeded()
        }
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

    func refreshCurrentGlobalAccuracy() async {
        do {
            let profile = try await realApi.getMyGlobalAccuracy()
            currentGlobalAccuracy = profile.accuracyRate
        } catch {
            // Non-fatal; global accuracy is a live enhancement and should not block the UI.
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
            if userGuilds.isEmpty, isAuthenticated {
                _ = try await assignOnboardingGuild(showTransition: false)
            } else {
                showGuildSelectionSheet = true
            }
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
            
            showSuccess(RLUserFacingCopy.format(.successJoinedGuildNamed, guildWithMembership.guild.name))
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

    private func completePostAuthGuildSetup(context: String) async throws {
        if userGuilds.isEmpty {
            print("🔐 \(context): No guilds found - assigning onboarding guild")
            _ = try await assignOnboardingGuild(showTransition: false)
        } else {
            print("🔐 \(context): Guild selection required (\(userGuilds.count) guilds)")
            showGuildSelectionSheet = true
        }
        isHandlingAuthFlow = false
    }
    
    /// Create a new guild - returns the combined guild with membership
    func createGuild(
        name: String,
        description: String?,
        isOpen: Bool,
        language: String? = nil,
        location: String? = nil,
        joinQuestions: [RLGuildJoinQuestionInputDTO] = [],
        initialAnnouncementTitle: String,
        initialAnnouncementContent: String,
        initialAnnouncementPreview: String? = nil,
        initialAnnouncementIsImportant: Bool = true
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
                joinQuestions: joinQuestions,
                initialAnnouncementTitle: initialAnnouncementTitle,
                initialAnnouncementContent: initialAnnouncementContent,
                initialAnnouncementPreview: initialAnnouncementPreview,
                initialAnnouncementIsImportant: initialAnnouncementIsImportant
            )
            let guildWithMembership = response.asGuildWithMembership
            
            // Add to local guild list
            userGuilds.append(guildWithMembership)
            
            // Select the newly created guild (show transition)
            selectGuild(guildWithMembership, showTransition: true)
            
            showSuccess(RLUserFacingCopy.format(.successCreatedGuildNamed, guildWithMembership.guild.name))
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
            showSuccess(RLUserFacingCopy.text(.successJoinRequestSubmitted))
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
            showSuccess(RLUserFacingCopy.text(.successJoinRequestApproved))
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
            showSuccess(RLUserFacingCopy.text(.successJoinRequestDeclined))
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
            
            showSuccess(RLUserFacingCopy.text(.successAnnouncementPosted))
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
            
            showSuccess(RLUserFacingCopy.text(.successEventCreated))
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
            showSuccess(RLUserFacingCopy.text(.successGuildSettingsUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successInviteSent))
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
            showSuccess(RLUserFacingCopy.text(.successInviteCancelled))
        } catch {
            showError(error, title: "Failed to Cancel Invite", style: .toast)
            throw error
        }
    }

    /// Accept a guild invite
    func acceptGuildInvite(guildId: UUID, inviteId: UUID) async throws -> RLGuildWithMembership {
        do {
            let result = try await realApi.acceptGuildInvite(guildId: guildId, inviteId: inviteId)
            showSuccess(RLUserFacingCopy.text(.successJoinedGuild))
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
            showSuccess(RLUserFacingCopy.text(.successMemberBanned))
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
            showSuccess(RLUserFacingCopy.text(.successMemberUnbanned))
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
            showSuccess(RLUserFacingCopy.text(.successMemberKicked))
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
            showSuccess(RLUserFacingCopy.text(.successMemberMuted))
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
            showSuccess(RLUserFacingCopy.text(.successMemberUnmuted))
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
            showSuccess(RLUserFacingCopy.text(.successMemberSuspended))
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
            showSuccess(RLUserFacingCopy.text(.successMemberUnsuspended))
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
            showSuccess(RLUserFacingCopy.format(.successRoleUpdated, role))
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
            showSuccess(RLUserFacingCopy.format(.successReportAction, action))
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
            showSuccess(RLUserFacingCopy.text(.successProfileUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successProfileUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successAvatarUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successAvatarRemoved))
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
        clearAlert()
        do {
            return try await realApi.requestPasswordReset(identifier: identifier)
        } catch {
            showError(error, title: "Password Reset Failed", style: .alert)
            throw error
        }
    }

    /// Verify reset token before showing reset form.
    func verifyPasswordResetToken(_ token: String) async throws -> RLPasswordResetVerifyResponseDTO {
        clearAlert()
        do {
            return try await realApi.verifyPasswordResetToken(token)
        } catch {
            showError(error, title: "Invalid Reset Link", style: .alert)
            throw error
        }
    }

    /// Reset password with one-time token.
    func resetPassword(token: String, newPassword: String) async throws -> RLPasswordResetResponseDTO {
        clearAlert()
        do {
            let response = try await realApi.resetPassword(token: token, newPassword: newPassword)
            clearLocalSessionState(clearAlertState: true)
            return response
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
            showSuccess(RLUserFacingCopy.text(.successVerificationEmailSent))
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
            showSuccess(RLUserFacingCopy.text(.successPasswordUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successDateOfBirthUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successDataExportRequested))
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
            showSuccess(RLUserFacingCopy.text(.successSupportTicketSubmitted))
            return response
        } catch {
            showError(error, title: "Failed to Send Support Ticket", style: .toast)
            throw error
        }
    }

    /// Delete account permanently. `password` is required only for email/password accounts.
    func deleteAccount(password: String?, confirmation: String) async throws {
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
            showSuccess(RLUserFacingCopy.text(.successFriendRequestSent))
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
            showSuccess(RLUserFacingCopy.text(.successFriendRequestAccepted))
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
            showSuccess(RLUserFacingCopy.text(.successFriendRequestDeclined))
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
            showSuccess(RLUserFacingCopy.text(.successFriendRemoved))
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
            showSuccess(RLUserFacingCopy.text(.successUserBlocked))
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
            showSuccess(RLUserFacingCopy.text(.successUserUnblocked))
            return response
        } catch {
            showError(error, title: "Failed to Unblock User", style: .toast)
            throw error
        }
    }
    
    
    

    
    // ================================================================================================
    // MARK: - Keychain Persistence
    // ================================================================================================

    private func clearLocalSessionState(clearAlertState: Bool) {
        realApi.clearTokens()
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        currentGuild = nil
        currentMembership = nil
        userSettings = nil
        userGuilds = []
        notificationStats = nil
        showGuildSelectionSheet = false
        showBetaWelcomeSheet = false
        isHandlingAuthFlow = false
        isOnboardingFlowActive = false
        showSignupWelcomeCarousel = false
        runtimeFlags = .disabled
        reportedUserStateVersion = 0
        clearBiometricAppLock()
        pendingSignupWelcomeUserId = nil
        pendingPasswordResetToken = nil
        onboardingState = nil
        accountCreatedDuringOnboarding = false
        appleSignUpPrefill = nil
        presenceByUserId.removeAll()
        currentPresenceChannel = nil
        hasShownOfflineToastForCurrentEpisode = false

        clearAllKeychain()
        resetChartReadyState()

        if clearAlertState {
            clearAlert()
        }
    }
    
    private var keychainPrefix: String {
        "traders_guild_\(AppConfig.sessionStorageNamespace)_"
    }

    private static func normalizedJWT(_ token: String) -> String? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let segments = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, segments.allSatisfy({ !$0.isEmpty }) else {
            return nil
        }

        return trimmed
    }

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

    // Onboarding State
    private func saveOnboardingState(_ state: RLOnboardingState?) {
        if let state = state {
            UserDefaults.standard.set(state.rawValue, forKey: "\(keychainPrefix)onboarding_state")
        } else {
            UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)onboarding_state")
        }
    }

    private func getOnboardingStateFromKeychain() -> RLOnboardingState? {
        guard let raw = UserDefaults.standard.string(forKey: "\(keychainPrefix)onboarding_state") else { return nil }
        return RLOnboardingState(rawValue: raw)
    }

    private func clearOnboardingState() {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)onboarding_state")
    }

    private func queueSignupWelcomeCarouselIfNeeded() {
        guard let userId = currentUser?.id else { return }
        guard !hasSeenSignupWelcomeCarousel(for: userId) else { return }
        pendingSignupWelcomeUserId = userId
    }

    private func presentPendingSignupWelcomeIfNeeded() {
        guard !showingTransition else { return }
        guard let userId = pendingSignupWelcomeUserId else { return }
        guard currentUser?.id == userId else {
            pendingSignupWelcomeUserId = nil
            return
        }

        if runtimeFlags.betaWelcomeEnabled && !hasSeenBetaWelcome(for: userId) {
            guard !showBetaWelcomeSheet else { return }
            markBetaWelcomeSeen(for: userId)
            showBetaWelcomeSheet = true
            return
        }

        guard !showBetaWelcomeSheet else { return }

        markSignupWelcomeCarouselSeen(for: userId)
        pendingSignupWelcomeUserId = nil
        showSignupWelcomeCarousel = true
    }

    private func hasSeenSignupWelcomeCarousel(for userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: signupWelcomeCarouselKey(for: userId))
    }

    private func markSignupWelcomeCarouselSeen(for userId: UUID) {
        UserDefaults.standard.set(true, forKey: signupWelcomeCarouselKey(for: userId))
    }

    private func signupWelcomeCarouselKey(for userId: UUID) -> String {
        "\(keychainPrefix)signup_welcome_seen_\(userId.uuidString)"
    }

    private func hasSeenBetaWelcome(for userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: betaWelcomeKey(for: userId))
    }

    private func markBetaWelcomeSeen(for userId: UUID) {
        UserDefaults.standard.set(true, forKey: betaWelcomeKey(for: userId))
    }

    private func betaWelcomeKey(for userId: UUID) -> String {
        "\(keychainPrefix)beta_welcome_seen_\(userId.uuidString)"
    }

    func hasReportedUser(guildId: UUID, userId: UUID) -> Bool {
        guard let reporterUserId = currentUser?.id else { return false }
        return reportedUserStore.isReported(
            reporterUserId: reporterUserId,
            guildId: guildId,
            reportedUserId: userId,
            namespace: AppConfig.sessionStorageNamespace
        )
    }

    private func markReportedUser(guildId: UUID, userId: UUID) {
        guard let reporterUserId = currentUser?.id else { return }
        reportedUserStore.markReported(
            reporterUserId: reporterUserId,
            guildId: guildId,
            reportedUserId: userId,
            namespace: AppConfig.sessionStorageNamespace
        )
        reportedUserStateVersion += 1
    }

    private func isDuplicateUserReportError(_ error: Error) -> Bool {
        switch error {
        case APIError.serverError(let statusCode, let detail):
            return statusCode == 409 && detail.localizedCaseInsensitiveContains("already reported")
        case APIError.badRequest(let detail):
            return detail.localizedCaseInsensitiveContains("already reported")
        default:
            return false
        }
    }

    // MARK: - In-App Tutorial Persistence

    func hasTutorialCompleted(for userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "\(keychainPrefix)tutorial_completed_\(userId.uuidString)")
    }

    func markTutorialCompleted(for userId: UUID) {
        UserDefaults.standard.set(true, forKey: "\(keychainPrefix)tutorial_completed_\(userId.uuidString)")
        clearTutorialProgress(for: userId)
    }

    func saveTutorialProgress(step: Int, for userId: UUID) {
        UserDefaults.standard.set(step, forKey: "\(keychainPrefix)tutorial_step_\(userId.uuidString)")
    }

    func getTutorialProgress(for userId: UUID) -> Int? {
        let key = "\(keychainPrefix)tutorial_step_\(userId.uuidString)"
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: key)
    }

    func clearTutorialProgress(for userId: UUID) {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)tutorial_step_\(userId.uuidString)")
    }

    func resetTutorial(for userId: UUID) {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)tutorial_completed_\(userId.uuidString)")
        clearTutorialProgress(for: userId)
    }

    // Clear all
    private func clearAllKeychain() {
        clearTokenFromKeychain()
        clearRefreshTokenFromKeychain()
        clearUserFromKeychain()
        clearGuildFromKeychain()
        clearMembershipFromKeychain()
        clearOnboardingState()
        BiometricAuthManager.shared.disableBiometric()
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
    func sendChatroomMessage(
        chatroomId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachments: [RLMessageAttachmentDTO] = [],
        replyToMessageId: UUID? = nil
    ) async throws -> RLChatroomMessageDTO {
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
                attachmentName: attachmentName,
                attachments: attachments,
                replyToMessageId: replyToMessageId
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
            showSuccess(RLUserFacingCopy.text(.successMessageUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successMessageDeleted))
        } catch {
            showError(error, title: "Failed to Delete Message", style: .toast)
            throw error
        }
    }

    func toggleChatroomMessageReaction(
        chatroomId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLChatroomMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.toggleChatroomMessageReaction(
                guildId: guild.id,
                chatroomId: chatroomId,
                messageId: messageId,
                emoji: emoji
            )
        } catch {
            showError(error, title: "Failed to Update Reaction", style: .toast)
            throw error
        }
    }

    func fetchChatroomMessageReactionReactors(
        chatroomId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await realApi.getChatroomMessageReactionReactors(
            guildId: guild.id,
            chatroomId: chatroomId,
            messageId: messageId,
            emoji: emoji
        )
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
                showSuccess(RLUserFacingCopy.text(.successChatroomPinned))
            } else if isPinned == false {
                showSuccess(RLUserFacingCopy.text(.successChatroomUnpinned))
            }
            if isMuted == true {
                showSuccess(RLUserFacingCopy.text(.successChatroomMuted))
            } else if isMuted == false {
                showSuccess(RLUserFacingCopy.text(.successChatroomUnmuted))
            }
            return settings
        } catch {
            showError(error, title: "Failed to Update Settings", style: .toast)
            throw error
        }
    }
    
    /// Create a new chatroom (owner/admin only)
    func createChatroom(
        name: String,
        description: String,
        icon: String? = nil
    ) async throws -> RLGuildChatroomDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            let chatroom = try await realApi.createChatroom(
                guildId: guild.id,
                name: name,
                description: description,
                icon: icon
            )
            showSuccess(RLUserFacingCopy.text(.successChatroomCreated))
            return chatroom
        } catch {
            showError(error, title: "Failed to Create Chatroom", style: .toast)
            throw error
        }
    }

    /// Update chatroom metadata (owner/admin only)
    func updateChatroom(
        chatroomId: UUID,
        name: String? = nil,
        description: String? = nil,
        icon: String? = nil
    ) async throws -> RLGuildChatroomDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            let chatroom = try await realApi.updateChatroom(
                guildId: guild.id,
                chatroomId: chatroomId,
                name: name,
                description: description,
                icon: icon
            )
            showSuccess(RLUserFacingCopy.text(.successChatroomUpdated))
            return chatroom
        } catch {
            showError(error, title: "Failed to Update Chatroom", style: .toast)
            throw error
        }
    }

    /// Archive chatroom (owner/admin only)
    func deleteChatroom(chatroomId: UUID) async throws {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            _ = try await realApi.deleteChatroom(guildId: guild.id, chatroomId: chatroomId)
            showSuccess(RLUserFacingCopy.text(.successChatroomArchived))
        } catch {
            showError(error, title: "Failed to Archive Chatroom", style: .toast)
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
    func sendDMMessage(
        threadId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachments: [RLMessageAttachmentDTO] = [],
        replyToMessageId: UUID? = nil
    ) async throws -> RLDMMessageDTO {
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
                attachmentName: attachmentName,
                attachments: attachments,
                replyToMessageId: replyToMessageId
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
            showSuccess(RLUserFacingCopy.text(.successMessageUpdated))
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
            showSuccess(RLUserFacingCopy.text(.successMessageDeleted))
        } catch {
            showError(error, title: "Failed to Delete Message", style: .toast)
            throw error
        }
    }

    func toggleDMMessageReaction(
        threadId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLDMMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.toggleDMMessageReaction(
                guildId: guild.id,
                threadId: threadId,
                messageId: messageId,
                emoji: emoji
            )
        } catch {
            showError(error, title: "Failed to Update Reaction", style: .toast)
            throw error
        }
    }

    func fetchDMMessageReactionReactors(
        threadId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await realApi.getDMMessageReactionReactors(
            guildId: guild.id,
            threadId: threadId,
            messageId: messageId,
            emoji: emoji
        )
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
            showSuccess(RLUserFacingCopy.text(.successConversationDeleted))
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

                // Clear map on guild change — fallback to DTO isOnline until fresh events arrive
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

        // 4. Clear stale presence data on WebSocket reconnection
        // After reconnect, channels are re-subscribed automatically by RealTimeService.
        // Clear the map so effectiveOnlineStatus falls back to DTO isOnline until fresh events arrive.
        RealTimeService.shared.$connectionStatus
            .removeDuplicates()
            .scan((previous: RealTimeConnectionStatus.disconnected, current: RealTimeConnectionStatus.disconnected)) { state, newStatus in
                (previous: state.current, current: newStatus)
            }
            .filter { $0.previous != .connected && $0.current == .connected }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.shouldShowPresence else { return }
                // Clear stale presence so we use fallback until fresh events arrive
                self.presenceByUserId.removeAll()
                print("👀 [AppState] WebSocket reconnected — cleared stale presence data")
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
    func subscribeToNotifications(reason: PushRegistrationReason = .login) {
        guard let userId = currentUser?.id else { return }
        let channel = "user:\(userId):notifications"
        RealTimeService.shared.subscribe(to: [channel], owner: "notifications")

        Task {
            await PushNotificationManager.shared.requestPermissionAndRegister(reason: reason)
        }
    }

    /// Unsubscribe when logging out
    func unsubscribeFromNotifications() {
        guard let userId = currentUser?.id else { return }
        let channel = "user:\(userId):notifications"
        RealTimeService.shared.unsubscribe(from: [channel], owner: "notifications")

        Task {
            await PushNotificationManager.shared.deregisterToken()
        }
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
            showSuccess(RLUserFacingCopy.text(.successAddedGuildWatchlist))
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
            showSuccess(RLUserFacingCopy.text(.successRemovedGuildWatchlist))
        } catch {
            showError(error, title: "Failed to Remove Symbol", style: .toast)
            throw error
        }
    }
    
    /// Add symbol to personal watchlist
    func addToPersonalWatchlist(symbolId: UUID) async throws -> RLWatchlistSymbolDTO {
        do {
            let result = try await realApi.addToPersonalWatchlist(symbolId: symbolId)
            showSuccess(RLUserFacingCopy.text(.successAddedWatchlist))
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
            showSuccess(RLUserFacingCopy.text(.successRemovedWatchlist))
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
            showSuccess(RLUserFacingCopy.text(.successRequestSubmitted))
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
                candleLimit: candleLimit,
                continuousTime: true
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
    func sendChartChatMessage(
        chatId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachments: [RLMessageAttachmentDTO] = [],
        replyToMessageId: UUID? = nil
    ) async throws -> RLChartChatMessageDTO {
        do {
            return try await realApi.sendChartChatMessage(
                chatId: chatId,
                content: content,
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName,
                attachments: attachments,
                replyToMessageId: replyToMessageId
            )
        } catch {
            showError(error, title: "Failed to Send Message", style: .toast)
            throw error
        }
    }

    func toggleChartChatMessageReaction(
        chatId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLChartChatMessageDTO {
        do {
            return try await realApi.toggleChartChatMessageReaction(
                chatId: chatId,
                messageId: messageId,
                emoji: emoji
            )
        } catch {
            showError(error, title: "Failed to Update Reaction", style: .toast)
            throw error
        }
    }

    func fetchChartChatMessageReactionReactors(
        chatId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        try await realApi.getChartChatMessageReactionReactors(
            chatId: chatId,
            messageId: messageId,
            emoji: emoji
        )
    }

    // =============================================================================================
    // MARK: - Reporting & Sharing (Pending backend support)
    // =============================================================================================

    func reportChatroom(guildId: UUID, chatroomId: UUID, reason: String) async throws {
        do {
            _ = try await realApi.reportChatroom(guildId: guildId, chatroomId: chatroomId, reason: reason)
            showSuccess(RLUserFacingCopy.text(.successReportSubmitted))
        } catch {
            showError(error, title: "Failed to Report Chatroom", style: .toast)
            throw error
        }
    }

    func reportUser(guildId: UUID, userId: UUID, reason: String) async throws {
        do {
            _ = try await realApi.reportUser(guildId: guildId, userId: userId, reason: reason)
            markReportedUser(guildId: guildId, userId: userId)
            showSuccess(RLUserFacingCopy.text(.successReportSubmitted))
        } catch {
            if isDuplicateUserReportError(error) {
                markReportedUser(guildId: guildId, userId: userId)
                showInfo("You already reported this user. Moderators will review it.")
                return
            }
            showError(error, title: "Failed to Report User", style: .toast)
            throw error
        }
    }

    func shareEvent(guildId: UUID, eventId: UUID, friendId: UUID) async throws {
        do {
            _ = try await realApi.shareEvent(guildId: guildId, eventId: eventId, friendId: friendId)
            showSuccess(RLUserFacingCopy.text(.successEventShared))
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

    /// Posted when a guild member's live reputation/accuracy snapshot changes.
    /// userInfo mirrors RLGuildMemberPerformanceUpdatePayload plus parsed UUIDs where possible.
    static let guildMemberPerformanceDidUpdate = Notification.Name("guildMemberPerformanceDidUpdate")

    /// Posted when marker activity should refresh after lifecycle or result events.
    /// userInfo: ["guildId": UUID?]
    static let markerActivityDidChange = Notification.Name("markerActivityDidChange")

    /// Posted when a marker share card is tapped inside chat.
    /// userInfo: ["markerId": String, "symbolId": String, "timeframe": String, "candleTimestamp": Date, "symbolTicker": String?]
    static let openSharedMarker = Notification.Name("openSharedMarker")

    /// Posted after chart symbol/timeframe has been prepared for a shared marker.
    /// userInfo mirrors openSharedMarker payload.
    static let focusSharedMarker = Notification.Name("focusSharedMarker")
}
