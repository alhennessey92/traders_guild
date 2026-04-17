//
//  UserSettingsView.swift
//  traders_guild
//
//  COMPLETE SETTINGS VIEW WITH BACKEND INTEGRATION
//  Full navigation to all settings subviews with proper state management.
//  
//  Created by Al Hennessey on 12/10/2025.
//  Updated: 30/01/2026 - Fully integrated with backend APIs
//

import SwiftUI
import StoreKit


struct UserSettingsSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState
    
    let onBack: () -> Void
    
    // Navigation state
    @State private var currentDestination: SettingsDestination? = nil
    
    // Alert states
    @State private var showLogoutConfirmation = false
    
    // Global settings states (synced from backend)
    @State private var showGlobalOnlineStatus = true
    @State private var allowFriendRequests = true
    @State private var dmPermissionMode: RLDMPermissionMode = .all
    @State private var isSyncingSettings = false

    // Biometric
    private let biometricManager = BiometricAuthManager.shared
    @State private var isBiometricEnabled = BiometricAuthManager.shared.isBiometricEnabled
    
    var body: some View {
        ZStack {
            // Background
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            // Navigation content
            if let destination = currentDestination {
                navigationDestinationView(destination)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                mainSettingsView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentDestination)
        .task {
            await loadUserSettingsIfNeeded()
        }
        .onReceive(rlAppState.$userSettings) { settings in
            if let settings = settings {
                syncSettingsFromState(settings)
            }
        }
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                rlAppState.logout()
                onBack()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }
    
    // MARK: - Navigation Destination View
    
    @ViewBuilder
    private func navigationDestinationView(_ destination: SettingsDestination) -> some View {
        switch destination {
        case .editProfile:
            EditProfileView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .avatarSelection:
            AvatarSelectionView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .changeEmail:
            ChangeEmailView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)

        case .verifyEmail:
            NavigationStack {
                EmailVerificationView(
                    userEmail: rlAppState.currentUser?.email ?? "",
                    onContinue: {
                        currentDestination = nil
                    },
                    showSkipUnverifiedOption: false
                )
                .environmentObject(rlAppState)
            }
            
        case .changePassword:
            ChangePasswordView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .dateOfBirth:
            DateOfBirthView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .tradingInterests:
            TradingInterestsView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .blockedUsers:
            BlockedUsersView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .dataPrivacy:
            DataPrivacyView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)

        case .pushNotifications:
            PushNotificationSettingsView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)

        case .helpCenter:
            HelpCenterView(
                onBack: { currentDestination = nil },
                onContactSupport: { currentDestination = .contactSupport }
            )
            
        case .contactSupport:
            ContactSupportView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .rateApp:
            // This would normally open the App Store
            EmptyView()
                .onAppear { 
                    requestAppReview()
                    currentDestination = nil 
                }
            
        case .termsPrivacy:
            TermsPrivacyView(onBack: { currentDestination = nil })
            
        case .about:
            AboutView(onBack: { currentDestination = nil })
            
        case .leaveGuild:
            // Orphaned destination (entry point removed), keeping for compilation safety
            EmptyView()
                .onAppear { currentDestination = nil }
            
        case .deleteAccount:
            DeleteAccountConfirmationView(
                onBack: { currentDestination = nil },
                onDelete: {
                    // Account deletion handled by DeleteAccountConfirmationView
                    // It calls rlAppState.deleteAccount() which clears all state
                    currentDestination = nil
                    onBack() // Close settings sheet after deletion
                }
            )
            .environmentObject(rlAppState)
        }
    }
    
    // MARK: - Main Settings View
    
    private var mainSettingsView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with Back Button
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                            Text("Back")
                                .font(.headline)
                        }
                        .foregroundColor(AppColors.whiteText)
                    }
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                            .font(.headline)
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // GLOBAL ACCOUNT SETTINGS SECTION
                globalSettingsSection

                // HELP & SUPPORT SECTION
                tutorialSection

                // LOGOUT SECTION
                logoutSection
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Global Settings Section
    
    private var globalSettingsSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.circle")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText.opacity(0.9))
                Text("Account Settings")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 10)
            .padding(.top, 20)

            if let user = rlAppState.currentUser, !user.isVerified {
                SettingsSectionHeader(title: "Verification Required")

                Button {
                    withAnimation {
                        currentDestination = .verifyEmail
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.statusWarning95)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Verify your email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.whiteText)
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text("Enter your code or resend the verification email to unlock full access.")
                                .font(.caption2)
                                .foregroundColor(AppColors.statusWarning95)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.statusWarning95)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.statusWarning80.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(AppColors.statusWarning80.opacity(0.55), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .buttonStyle(.plain)
            }

            // Account & Profile
            SettingsSectionHeader(title: "Profile")

            if let user = rlAppState.currentUser {
                let isEffectivelyOnline = rlAppState.effectiveOnlineStatus(
                    userId: user.id,
                    fallback: user.isOnline
                )
                // User info display
                HStack(spacing: 12) {
                    UnifiedMemberAvatar(
                        username: user.displayName,
                        avatarURL: user.avatarUrl,
                        isOnline: isEffectivelyOnline,
                        size: 50
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)

                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(AppColors.greyText.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                .padding()
                .background(AppColors.insetPanelBackground)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .onTapGesture {
                    withAnimation {
                        currentDestination = .editProfile
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsButtonRow(
                    icon: "person.fill",
                    title: "Edit Profile",
                    subtitle: "Update your name, bio, and location",
                    iconColor: AppColors.accentColor
                ) {
                    withAnimation {
                        currentDestination = .editProfile
                    }
                }

                SettingsButtonRow(
                    icon: "photo.fill",
                    title: "Change Avatar",
                    subtitle: "Upload a new profile picture",
                    iconColor: .blue
                ) {
                    withAnimation {
                        currentDestination = .avatarSelection
                    }
                }

                SettingsButtonRow(
                    icon: "envelope.fill",
                    title: "Change Email",
                    subtitle: "Update your email address",
                    iconColor: .green
                ) {
                    withAnimation {
                        currentDestination = .changeEmail
                    }
                }

                SettingsButtonRow(
                    icon: "lock.fill",
                    title: "Change Password",
                    subtitle: "Update your password",
                    iconColor: .orange
                ) {
                    withAnimation {
                        currentDestination = .changePassword
                    }
                }

                SettingsButtonRow(
                    icon: "calendar",
                    title: "Date of Birth",
                    subtitle: "Update your date of birth",
                    iconColor: .purple
                ) {
                    withAnimation {
                        currentDestination = .dateOfBirth
                    }
                }

                SettingsButtonRow(
                    icon: "chart.xyaxis.line",
                    title: "Trading Interests",
                    subtitle: "Select your trading preferences",
                    iconColor: .cyan
                ) {
                    withAnimation {
                        currentDestination = .tradingInterests
                    }
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Privacy section
            SettingsSectionHeader(title: "Privacy")

            VStack(alignment: .leading, spacing: 8) {
                SettingsToggleRow(
                    icon: "circle.fill",
                    title: "Show Online Status",
                    subtitle: "Let others see when you're online",
                    isOn: $showGlobalOnlineStatus,
                    iconColor: AppColors.bullCandleGreen
                )
                .padding(.horizontal, 16)
                .onChange(of: showGlobalOnlineStatus) { _, newValue in
                    updateUserSettings(showOnlineStatus: newValue)
                }

                SettingsToggleRow(
                    icon: "person.badge.plus",
                    title: "Allow Friend Requests",
                    subtitle: "Let others send you friend requests",
                    isOn: $allowFriendRequests,
                    iconColor: .blue
                )
                .padding(.horizontal, 16)
                .onChange(of: allowFriendRequests) { _, newValue in
                    updateUserSettings(allowFriendRequests: newValue)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Direct Messages")
                                .font(.subheadline)
                                .foregroundColor(AppColors.whiteText)
                            Text(dmPermissionMode.subtitle)
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        }
                        Spacer()
                    }

                    Picker("Direct Messages", selection: $dmPermissionMode) {
                        ForEach(RLDMPermissionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.insetPanelBackground)
                )
                .padding(.horizontal, 16)
                .onChange(of: dmPermissionMode) { _, newValue in
                    updateUserSettings(dmPermissionMode: newValue)
                }

                SettingsButtonRow(
                    icon: "hand.raised.fill",
                    title: "Blocked Users",
                    subtitle: "Manage blocked accounts",
                    iconColor: .red
                ) {
                    withAnimation {
                        currentDestination = .blockedUsers
                    }
                }

                SettingsButtonRow(
                    icon: "eye.slash.fill",
                    title: "Data & Privacy",
                    subtitle: "Control your data and visibility",
                    iconColor: .purple
                ) {
                    withAnimation {
                        currentDestination = .dataPrivacy
                    }
                }

                SettingsButtonRow(
                    icon: "bell.badge.fill",
                    title: "Push Notifications",
                    subtitle: "Manage which notifications you receive",
                    iconColor: .red
                ) {
                    withAnimation {
                        currentDestination = .pushNotifications
                    }
                }
            }

            // Security (biometric toggle -- only shown when device supports it)
            if biometricManager.isBiometricAvailable {
                Divider()
                    .background(AppColors.whiteText.opacity(0.2))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                SettingsSectionHeader(title: "Security")

                VStack(alignment: .leading, spacing: 8) {
                    SettingsToggleRow(
                        icon: biometricManager.biometricIconName,
                        title: biometricManager.biometricName,
                        subtitle: "Use \(biometricManager.biometricName) for faster access when opening the app",
                        isOn: $isBiometricEnabled,
                        iconColor: AppColors.accentColor
                    )
                    .padding(.horizontal, 16)
                    .onChange(of: isBiometricEnabled) { _, newValue in
                        handleBiometricToggle(enabled: newValue)
                    }
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Appearance
            SettingsSectionHeader(title: "Appearance")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(.cyan)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText)
                        Text("Choose your preferred app theme")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                ThemeManager.shared.currentTheme = theme
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(theme.swatchColor)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(ThemeManager.shared.currentTheme == theme
                                                ? AppColors.accentColor : AppColors.adaptiveOverlay20,
                                                lineWidth: ThemeManager.shared.currentTheme == theme ? 2.5 : 1)
                                    )

                                Text(theme.displayName)
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.currentTheme == theme
                                        ? AppColors.whiteText : AppColors.greyText)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.insetPanelBackground)
            )
            .padding(.horizontal, 16)

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Help & Support
            SettingsSectionHeader(title: "Help & Support")

            VStack(alignment: .leading, spacing: 8) {
                SettingsButtonRow(
                    icon: "questionmark.circle.fill",
                    title: "Help Center",
                    subtitle: "FAQs and tutorials",
                    iconColor: .blue
                ) {
                    withAnimation {
                        currentDestination = .helpCenter
                    }
                }

                SettingsButtonRow(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    subtitle: "Get help from our team",
                    iconColor: AppColors.accentColor
                ) {
                    withAnimation {
                        currentDestination = .contactSupport
                    }
                }

                SettingsButtonRow(
                    icon: "star.fill",
                    title: "Rate the App",
                    subtitle: "Share your feedback",
                    iconColor: .yellow
                ) {
                    requestAppReview()
                }

                SettingsButtonRow(
                    icon: "doc.text.fill",
                    title: "Terms & Privacy",
                    subtitle: "Legal information",
                    iconColor: .gray
                ) {
                    withAnimation {
                        currentDestination = .termsPrivacy
                    }
                }

                SettingsButtonRow(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: "Version and app information",
                    iconColor: .purple
                ) {
                    withAnimation {
                        currentDestination = .about
                    }
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Account Management
            SettingsSectionHeader(title: "Account Management")

            VStack(alignment: .leading, spacing: 8) {
                SettingsButtonRow(
                    icon: "trash.fill",
                    title: "Delete Account",
                    subtitle: "Permanently delete your account",
                    iconColor: .red
                ) {
                    withAnimation {
                        currentDestination = .deleteAccount
                    }
                }
            }
        }
    }
    
    // MARK: - Tutorial Section

    private var tutorialCompleted: Bool {
        guard let userId = rlAppState.currentUser?.id else { return false }
        return rlAppState.hasTutorialCompleted(for: userId)
    }

    private var tutorialSubtitle: String {
        if tutorialCompleted {
            return "Review the guided tour"
        }
        guard let userId = rlAppState.currentUser?.id,
              rlAppState.getTutorialProgress(for: userId) != nil else {
            return "Take a guided tour of the app"
        }
        return "Continue the guided tour"
    }

    private var tutorialSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)

            SettingsSectionHeader(title: "Help & Support")

            VStack(alignment: .leading, spacing: 8) {
                SettingsButtonRow(
                    icon: "graduationcap.fill",
                    title: "App Tutorial",
                    subtitle: tutorialSubtitle,
                    iconColor: AppColors.accentColor
                ) {
                    NotificationCenter.default.post(
                        name: .startTutorial,
                        object: nil,
                        userInfo: ["fromBeginning": tutorialCompleted]
                    )
                }

                SettingsButtonRow(
                    icon: "flask.fill",
                    title: "Beta Welcome",
                    subtitle: "Review the beta program overview",
                    iconColor: AppColors.accentColor
                ) {
                    rlAppState.presentBetaWelcomeFromSettings()
                }
            }
        }
    }

    // MARK: - Logout Section

    private var logoutSection: some View {
        VStack(spacing: 0) {
            Divider()
            Rectangle()
                .fill(AppColors.sheetBackground.opacity(0.5))
                .frame(height: 20)
            Divider()
            
            Button(action: {
                showLogoutConfirmation = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(width: 30)

                    Text("Logout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    Spacer()
                }
                .padding()
                .background(AppColors.statusNegative10)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.statusNegative30, lineWidth: 1)
                )
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Actions
    
    private func loadUserSettingsIfNeeded() async {
        if rlAppState.userSettings == nil {
            _ = try? await rlAppState.fetchUserSettings()
        }
    }
    
    private func syncSettingsFromState(_ settings: RLUserSettingsDTO) {
        isSyncingSettings = true
        showGlobalOnlineStatus = settings.showOnlineStatus
        allowFriendRequests = settings.allowFriendRequests
        dmPermissionMode = settings.dmPermission
        isSyncingSettings = false
    }
    
    private func updateUserSettings(
        showOnlineStatus: Bool? = nil,
        allowFriendRequests: Bool? = nil,
        dmPermissionMode: RLDMPermissionMode? = nil
    ) {
        guard !isSyncingSettings else { return }
        Task {
            do {
                let request = RLUserSettingsUpdateRequest(
                    showOnlineStatus: showOnlineStatus,
                    allowFriendRequests: allowFriendRequests,
                    activityVisible: nil,
                    analyticsEnabled: nil,
                    personalizedContentEnabled: nil,
                    dmPermissionMode: dmPermissionMode?.rawValue
                )
                let updated = try await rlAppState.updateUserSettings(request)
                syncSettingsFromState(updated)
            } catch {
                print("Failed to update user settings: \(error)")
            }
        }
    }
    
    private func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    private func handleBiometricToggle(enabled: Bool) {
        if enabled {
            Task {
                do {
                    let authenticated = try await biometricManager.authenticate(
                        reason: "Confirm your identity to enable \(biometricManager.biometricName)"
                    )
                    guard authenticated else {
                        await MainActor.run { isBiometricEnabled = false }
                        return
                    }

                    if let refreshToken = rlAppState.currentRefreshToken {
                        try biometricManager.storeBiometricRefreshToken(refreshToken)
                        biometricManager.isBiometricEnabled = true
                        rlAppState.showSuccess("\(biometricManager.biometricName) enabled!")
                    } else {
                        await MainActor.run { isBiometricEnabled = false }
                        rlAppState.showError(NSError(
                            domain: "", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "No active session found. Please sign in again."]
                        ))
                    }
                } catch {
                    await MainActor.run { isBiometricEnabled = false }
                    if (error as NSError).code != -2 {
                        rlAppState.showError(error)
                    }
                }
            }
        } else {
            biometricManager.disableBiometric()
            rlAppState.showSuccess("\(biometricManager.biometricName) disabled")
        }
    }
}


// MARK: - Preview

#Preview {
    UserSettingsSheetView(onBack: {})
        .environmentObject(RLAppState())
        .preferredColorScheme(ThemeManager.shared.currentTheme.colorScheme)
}
