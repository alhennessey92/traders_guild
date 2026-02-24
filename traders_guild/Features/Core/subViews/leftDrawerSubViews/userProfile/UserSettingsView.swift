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
    @State private var isSyncingSettings = false
    
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
            
        case .helpCenter:
            HelpCenterView(onBack: { currentDestination = nil })
            
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
            
            // Account & Profile
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Profile")
                
                if let user = rlAppState.currentUser {
                    // User info display
                    HStack(spacing: 12) {
                        UnifiedMemberAvatar(
                            username: user.displayName,
                            avatarURL: user.avatarUrl,
                            isOnline: user.isOnline,
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
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 12)
                    .onTapGesture {
                        withAnimation {
                            currentDestination = .editProfile
                        }
                    }
                }
                
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
            
            // Privacy section
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Privacy")
                
                SettingsToggleRow(
                    icon: "circle.fill",
                    title: "Show Online Status",
                    subtitle: "Let others see when you're online",
                    isOn: $showGlobalOnlineStatus,
                    iconColor: AppColors.bullCandleGreen
                )
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
                .onChange(of: allowFriendRequests) { _, newValue in
                    updateUserSettings(allowFriendRequests: newValue)
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
            }
            
            Divider()
            
            // Help & Support
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Help & Support")
                
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
            
            // Account Management
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Account Management")
                
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
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Actions
    
    private func loadUserSettingsIfNeeded() async {
        if rlAppState.userSettings == nil {
            try? await rlAppState.fetchUserSettings()
        }
    }
    
    private func syncSettingsFromState(_ settings: RLUserSettingsDTO) {
        isSyncingSettings = true
        showGlobalOnlineStatus = settings.showOnlineStatus
        allowFriendRequests = settings.allowFriendRequests
        isSyncingSettings = false
    }
    
    private func updateUserSettings(
        showOnlineStatus: Bool? = nil,
        allowFriendRequests: Bool? = nil
    ) {
        guard !isSyncingSettings else { return }
        Task {
            do {
                let request = RLUserSettingsUpdateRequest(
                    showOnlineStatus: showOnlineStatus,
                    allowFriendRequests: allowFriendRequests,
                    activityVisible: nil,
                    analyticsEnabled: nil,
                    personalizedContentEnabled: nil
                )
                let updated = try await rlAppState.updateUserSettings(request)
                syncSettingsFromState(updated)
            } catch {
                print("Failed to update user settings: \(error)")
            }
        }
    }
    
    private func requestAppReview() {
        // This would normally use StoreKit to request a review
        print("Requesting app review...")
        // TODO: Implement StoreKit review request
    }
}


// MARK: - Preview

#Preview {
    UserSettingsSheetView(onBack: {})
        .environmentObject(RLAppState())
        .preferredColorScheme(.dark)
}









// //
// //  UserSettingsView.swift
// //  traders_guild
// //
// //  UPDATED: Full navigation to all settings subviews with proper state management.
// //  Created by Al Hennessey on 12/10/2025.
// //  Updated: 29/01/2026 - Added full subview navigation
// //  Refactored: Removed Guild Settings section as requested.
// //

// import SwiftUI


// struct UserSettingsSheetView: View {
//     @EnvironmentObject var appState: AppState
//     @EnvironmentObject var rlAppState: RLAppState
    
//     let onBack: () -> Void
    
//     // Navigation state
//     @State private var currentDestination: SettingsDestination? = nil
    
//     // Alert states
//     @State private var showLogoutConfirmation = false
//     @State private var showDeleteAccountConfirmation = false
    
//     // Global notification states
//     @State private var globalDMNotifications = true
//     @State private var globalFriendRequests = true
//     @State private var globalGuildInvites = true
//     @State private var emailNotifications = true
    
//     // Global privacy states
//     @State private var showGlobalOnlineStatus = true
//     @State private var allowFriendRequests = true
//     @State private var showGlobalReputation = true

//     @State private var isSyncingSettings = false
    
//     var body: some View {
//         ZStack {
//             // Background
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             // Navigation content
//             if let destination = currentDestination {
//                 navigationDestinationView(destination)
//                     .transition(.asymmetric(
//                         insertion: .move(edge: .trailing).combined(with: .opacity),
//                         removal: .move(edge: .trailing).combined(with: .opacity)
//                     ))
//             } else {
//                 mainSettingsView
//                     .transition(.asymmetric(
//                         insertion: .move(edge: .leading).combined(with: .opacity),
//                         removal: .move(edge: .leading).combined(with: .opacity)
//                     ))
//             }
//         }
//         .animation(.easeInOut(duration: 0.25), value: currentDestination)
//         .task {
//             await loadUserSettingsIfNeeded()
//         }
//         .onReceive(rlAppState.$userSettings) { settings in
//             if let settings = settings {
//                 syncSettingsFromState(settings)
//             }
//         }
//         .alert("Logout", isPresented: $showLogoutConfirmation) {
//             Button("Cancel", role: .cancel) { }
//             Button("Logout", role: .destructive) {
//                 rlAppState.logout()
//                 onBack()
//             }
//         } message: {
//             Text("Are you sure you want to logout?")
//         }
//     }
    
//     // MARK: - Navigation Destination View
    
//     @ViewBuilder
//     private func navigationDestinationView(_ destination: SettingsDestination) -> some View {
//         switch destination {
//         case .editProfile:
//             EditProfileView(onBack: { currentDestination = nil })
//                 .environmentObject(rlAppState)
            
//         case .avatarSelection:
//             AvatarSelectionView(onBack: { currentDestination = nil })
//                 .environmentObject(rlAppState)
            
//         case .changeEmail:
//             ChangeEmailView(onBack: { currentDestination = nil })
//                 .environmentObject(rlAppState)
            
//         case .changePassword:
//             ChangePasswordView(onBack: { currentDestination = nil })
            
//         case .dateOfBirth:
//             DateOfBirthView(onBack: { currentDestination = nil })
//                 .environmentObject(rlAppState)
            
//         case .tradingInterests:
//             TradingInterestsView(onBack: { currentDestination = nil })
            
//         case .blockedUsers:
//             BlockedUsersView(onBack: { currentDestination = nil })
            
//         case .dataPrivacy:
//             DataPrivacyView(onBack: { currentDestination = nil })
//                 .environmentObject(rlAppState)
            
//         case .helpCenter:
//             HelpCenterView(onBack: { currentDestination = nil })
            
//         case .contactSupport:
//             ContactSupportView(onBack: { currentDestination = nil })
            
//         case .rateApp:
//             // This would normally open the App Store
//             // For now, navigate back immediately
//             EmptyView()
//                 .onAppear { currentDestination = nil }
            
//         case .termsPrivacy:
//             TermsPrivacyView(onBack: { currentDestination = nil })
            
//         case .about:
//             AboutView(onBack: { currentDestination = nil })
            
//         case .leaveGuild:
//             // Orphaned destination (entry point removed), keeping for compilation safety
//             // if enum is shared.
//             EmptyView()
//                 .onAppear { currentDestination = nil }
            
//         case .deleteAccount:
//             DeleteAccountConfirmationView(
//                 onBack: { currentDestination = nil },
//                 onDelete: {
//                     deleteAccount()
//                     currentDestination = nil
//                 }
//             )
//             .environmentObject(rlAppState)
//         }
//     }
    
//     // MARK: - Main Settings View
    
//     private var mainSettingsView: some View {
//         ScrollView {
//             VStack(spacing: 0) {
//                 // Header with Back Button
//                 HStack {
//                     Button(action: onBack) {
//                         HStack(spacing: 6) {
//                             Image(systemName: "chevron.left")
//                                 .font(.headline)
//                             Text("Back")
//                                 .font(.headline)
//                         }
//                         .foregroundColor(AppColors.whiteText)
//                     }
                    
//                     Spacer()
                    
//                     Text("Settings")
//                         .font(.title2)
//                         .fontWeight(.bold)
//                         .foregroundColor(AppColors.whiteText)
                    
//                     Spacer()
                    
//                     // Invisible button for balance
//                     HStack(spacing: 6) {
//                         Image(systemName: "chevron.left")
//                             .font(.headline)
//                         Text("Back")
//                             .font(.headline)
//                     }
//                     .opacity(0)
//                 }
//                 .padding(.horizontal, 25)
//                 .padding(.top, 20)
//                 .padding(.bottom, 10)
                
//                 // GLOBAL ACCOUNT SETTINGS SECTION
//                 globalSettingsSection
                
//                 // LOGOUT SECTION
//                 logoutSection
                
//                 Spacer(minLength: 100)
//             }
//         }
//     }
    
//     // MARK: - Global Settings Section
    
//     private var globalSettingsSection: some View {
//         VStack(spacing: 0) {
//             // Header
//             HStack {
//                 Image(systemName: "person.circle")
//                     .font(.title3)
//                     .fontWeight(.bold)
//                     .foregroundColor(AppColors.whiteText.opacity(0.9))
//                 Text("Account Settings")
//                     .font(.title3)
//                     .fontWeight(.bold)
//                     .foregroundColor(AppColors.whiteText)
//                 Spacer()
//             }
//             .padding(.horizontal, 25)
//             .padding(.bottom, 10)
//             .padding(.top, 20)
            
//             // Account & Profile
//             VStack(spacing: 0) {
//                 SettingsSectionHeader(title: "Profile")
                
//                 if let user = rlAppState.currentUser {
//                     // User info display
//                     HStack(spacing: 12) {
//                         Circle()
//                             .fill(AppColors.accentColor.opacity(0.3))
//                             .frame(width: 50, height: 50)
//                             .overlay(
//                                 Text(String(user.username.prefix(2)).uppercased())
//                                     .font(.headline)
//                                     .fontWeight(.bold)
//                                     .foregroundColor(AppColors.accentColor)
//                             )
                        
//                         VStack(alignment: .leading, spacing: 4) {
//                             Text(user.displayName)
//                                 .font(.headline)
//                                 .foregroundColor(AppColors.whiteText)
                            
//                             Text("@\(user.username)")
//                                 .font(.subheadline)
//                                 .foregroundColor(AppColors.greyText)
                            
//                             HStack(spacing: 4) {
//                                 Image(systemName: "shield.pattern.checkered")
//                                     .font(.caption2)
//                                     .foregroundColor(AppColors.accentColor)
//                                 Text("\(user.globalReputation) global reputation")
//                                     .font(.caption)
//                                     .foregroundColor(AppColors.accentColor)
//                             }
//                         }
                        
//                         Spacer()
//                     }
//                     .padding(.horizontal, 25)
//                     .padding(.vertical, 12)
//                 }
                
//                 SettingsButtonRow(
//                     icon: "person.fill",
//                     title: "Edit Profile",
//                     subtitle: "Name, username, and avatar",
//                     iconColor: AppColors.accentColor
//                 ) {
//                     withAnimation {
//                         currentDestination = .editProfile
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "envelope.fill",
//                     title: "Email",
//                     subtitle: rlAppState.currentUser?.email ?? "Update email address",
//                     iconColor: .blue
//                 ) {
//                     withAnimation {
//                         currentDestination = .changeEmail
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "key.fill",
//                     title: "Change Password",
//                     subtitle: "Update your account password",
//                     iconColor: .orange
//                 ) {
//                     withAnimation {
//                         currentDestination = .changePassword
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "calendar.badge.clock",
//                     title: "Date of Birth",
//                     subtitle: "Update your birth date",
//                     iconColor: .purple
//                 ) {
//                     withAnimation {
//                         currentDestination = .dateOfBirth
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "tag.fill",
//                     title: "Trading Interests",
//                     subtitle: "Topics and markets you follow",
//                     iconColor: AppColors.bullCandleGreen
//                 ) {
//                     withAnimation {
//                         currentDestination = .tradingInterests
//                     }
//                 }
//             }
            
//             Divider()
            
//             // Global Privacy
//             VStack(spacing: 0) {
//                 SettingsSectionHeader(title: "Privacy & Safety")
                
//                 SettingsToggleRow(
//                     icon: "circle.fill",
//                     title: "Show Online Status",
//                     subtitle: "Let others see when you're online",
//                     isOn: $showGlobalOnlineStatus,
//                     iconColor: AppColors.bullCandleGreen
//                 )
//                 .onChange(of: showGlobalOnlineStatus) { _, newValue in
//                     updateUserSettings(showOnlineStatus: newValue)
//                 }
                
//                 SettingsToggleRow(
//                     icon: "person.badge.plus",
//                     title: "Allow Friend Requests",
//                     subtitle: "Let others send you friend requests",
//                     isOn: $allowFriendRequests,
//                     iconColor: .blue
//                 )
//                 .onChange(of: allowFriendRequests) { _, newValue in
//                     updateUserSettings(allowFriendRequests: newValue)
//                 }
                
                
//                 SettingsButtonRow(
//                     icon: "hand.raised.fill",
//                     title: "Blocked Users",
//                     subtitle: "Manage blocked accounts",
//                     iconColor: .red
//                 ) {
//                     withAnimation {
//                         currentDestination = .blockedUsers
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "eye.slash.fill",
//                     title: "Data & Privacy",
//                     subtitle: "Control your data and visibility",
//                     iconColor: .purple
//                 ) {
//                     withAnimation {
//                         currentDestination = .dataPrivacy
//                     }
//                 }
//             }
            
//             Divider()
            
//             // Help & Support
//             VStack(spacing: 0) {
//                 SettingsSectionHeader(title: "Help & Support")
                
//                 SettingsButtonRow(
//                     icon: "questionmark.circle.fill",
//                     title: "Help Center",
//                     subtitle: "FAQs and tutorials",
//                     iconColor: .blue
//                 ) {
//                     withAnimation {
//                         currentDestination = .helpCenter
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "envelope.fill",
//                     title: "Contact Support",
//                     subtitle: "Get help from our team",
//                     iconColor: AppColors.accentColor
//                 ) {
//                     withAnimation {
//                         currentDestination = .contactSupport
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "star.fill",
//                     title: "Rate the App",
//                     subtitle: "Share your feedback",
//                     iconColor: .yellow
//                 ) {
//                     requestAppReview()
//                 }
                
//                 SettingsButtonRow(
//                     icon: "doc.text.fill",
//                     title: "Terms & Privacy",
//                     subtitle: "Legal information",
//                     iconColor: .gray
//                 ) {
//                     withAnimation {
//                         currentDestination = .termsPrivacy
//                     }
//                 }
                
//                 SettingsButtonRow(
//                     icon: "info.circle.fill",
//                     title: "About",
//                     subtitle: "Version and app information",
//                     iconColor: .purple
//                 ) {
//                     withAnimation {
//                         currentDestination = .about
//                     }
//                 }
//             }
            
//             Divider()
            
//             // Account Management
//             VStack(spacing: 0) {
//                 SettingsSectionHeader(title: "Account Management")
                
//                 SettingsButtonRow(
//                     icon: "trash.fill",
//                     title: "Delete Account",
//                     subtitle: "Permanently delete your account",
//                     iconColor: .red
//                 ) {
//                     withAnimation {
//                         currentDestination = .deleteAccount
//                     }
//                 }
//             }
//         }
//     }
    
//     // MARK: - Logout Section
    
//     private var logoutSection: some View {
//         VStack(spacing: 0) {
//             Divider()
//             Rectangle()
//                 .fill(AppColors.sheetBackground.opacity(0.5))
//                 .frame(height: 20)
//             Divider()
            
//             Button(action: {
//                 showLogoutConfirmation = true
//             }) {
//                 HStack {
//                     Image(systemName: "rectangle.portrait.and.arrow.right")
//                         .font(.headline)
//                         .foregroundColor(.red)
//                         .frame(width: 30)
                    
//                     Text("Logout")
//                         .font(.subheadline)
//                         .fontWeight(.semibold)
//                         .foregroundColor(.red)
                    
//                     Spacer()
//                 }
//                 .padding()
//                 .background(Color.red.opacity(0.1))
//                 .cornerRadius(10)
//                 .overlay(
//                     RoundedRectangle(cornerRadius: 10)
//                         .stroke(Color.red.opacity(0.3), lineWidth: 1)
//                 )
//             }
//             .padding(.horizontal, 25)
//             .padding(.top, 20)
//         }
//     }
    
//     // MARK: - Actions
    
//     private func deleteAccount() {
//         Task {
//             do {
//                 // Future implementation: try await rlAppState.deleteUserAccount()
//                 // For now, logout
//                 rlAppState.logout()
//                 onBack()
//             } catch {
//                 print("Failed to delete account: \(error)")
//             }
//         }
//     }

//     private func loadUserSettingsIfNeeded() async {
//         if rlAppState.userSettings == nil {
//             try? await rlAppState.fetchUserSettings()
//         }
//     }

//     private func syncSettingsFromState(_ settings: RLUserSettingsDTO) {
//         isSyncingSettings = true
//         showGlobalOnlineStatus = settings.showOnlineStatus
//         allowFriendRequests = settings.allowFriendRequests
//         isSyncingSettings = false
//     }

//     private func updateUserSettings(
//         showOnlineStatus: Bool? = nil,
//         allowFriendRequests: Bool? = nil
//     ) {
//         guard !isSyncingSettings else { return }
//         Task {
//             do {
//                 let request = RLUserSettingsUpdateRequest(
//                     showOnlineStatus: showOnlineStatus,
//                     allowFriendRequests: allowFriendRequests,
//                     activityVisible: nil,
//                     analyticsEnabled: nil,
//                     personalizedContentEnabled: nil
//                 )
//                 let updated = try await rlAppState.updateUserSettings(request)
//                 syncSettingsFromState(updated)
//             } catch {
//                 print("Failed to update user settings: \(error)")
//             }
//         }
//     }
    
//     private func requestAppReview() {
//         // This would normally use StoreKit to request a review
//         print("Requesting app review...")
//     }
// }


// // MARK: - Preview

// #Preview {
//     UserSettingsSheetView(onBack: {})
//         .environmentObject(AppState())
//         .environmentObject(RLAppState())
//         .preferredColorScheme(.dark)
// }





