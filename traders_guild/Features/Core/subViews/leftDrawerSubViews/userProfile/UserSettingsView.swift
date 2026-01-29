//
//  UserSettingsView.swift
//  traders_guild
//
//  UPDATED: Full navigation to all settings subviews with proper state management.
//  Created by Al Hennessey on 12/10/2025.
//  Updated: 29/01/2026 - Added full subview navigation
//

import SwiftUI


struct UserSettingsSheetView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var rlAppState: RLAppState
    
    let onBack: () -> Void
    
    // Navigation state
    @State private var currentDestination: SettingsDestination? = nil
    
    // Alert states
    @State private var showLogoutConfirmation = false
    @State private var showLeaveGuildConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    
    // Current Guild notification states
    @State private var guildNotificationsEnabled = true
    @State private var guildAnnouncementsEnabled = true
    @State private var guildEventsEnabled = true
    @State private var guildMarkersEnabled = true
    @State private var guildChatEnabled = true
    @State private var guildDMsEnabled = true
    
    // Current Guild privacy states
    @State private var showOnlineStatusInGuild = true
    @State private var showActivityInGuild = true
    @State private var allowGuildDMs = true
    
    // Global notification states
    @State private var globalDMNotifications = true
    @State private var globalFriendRequests = true
    @State private var globalGuildInvites = true
    @State private var emailNotifications = true
    
    // Global privacy states
    @State private var showGlobalOnlineStatus = true
    @State private var allowFriendRequests = true
    @State private var showGlobalReputation = true
    
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
            
        case .dateOfBirth:
            DateOfBirthView(onBack: { currentDestination = nil })
                .environmentObject(rlAppState)
            
        case .tradingInterests:
            TradingInterestsView(onBack: { currentDestination = nil })
            
        case .blockedUsers:
            BlockedUsersView(onBack: { currentDestination = nil })
            
        case .dataPrivacy:
            DataPrivacyView(onBack: { currentDestination = nil })
            
        case .helpCenter:
            HelpCenterView(onBack: { currentDestination = nil })
            
        case .contactSupport:
            ContactSupportView(onBack: { currentDestination = nil })
            
        case .rateApp:
            // This would normally open the App Store
            // For now, navigate back immediately
            EmptyView()
                .onAppear { currentDestination = nil }
            
        case .termsPrivacy:
            TermsPrivacyView(onBack: { currentDestination = nil })
            
        case .about:
            AboutView(onBack: { currentDestination = nil })
            
        case .leaveGuild:
            LeaveGuildConfirmationView(
                onBack: { currentDestination = nil },
                onLeave: {
                    leaveGuild()
                    currentDestination = nil
                }
            )
            .environmentObject(rlAppState)
            
        case .deleteAccount:
            DeleteAccountConfirmationView(
                onBack: { currentDestination = nil },
                onDelete: {
                    deleteAccount()
                    currentDestination = nil
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
                
                // CURRENT GUILD SETTINGS SECTION (if in a guild)
                if let guild = rlAppState.currentGuild,
                   let membership = rlAppState.currentMembership {
                    guildSettingsSection(guild: guild, membership: membership)
                }
                
                // GLOBAL ACCOUNT SETTINGS SECTION
                globalSettingsSection
                
                // LOGOUT SECTION
                logoutSection
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Guild Settings Section
    
    @ViewBuilder
    private func guildSettingsSection(guild: RLGuildDTO, membership: RLGuildMembershipDTO) -> some View {
        VStack(spacing: 0) {
            // Guild Header
            HStack {
                Text("\(guild.name) Settings")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 10)
            
            // My Guild Membership Info
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "My Guild Membership")
                
                // Membership info display
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.accentColor.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Role:")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.greyText)
                                
                                Text(membership.memberRole.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(membership.memberRole.color)
                            }
                            
                            Text(membership.memberSince)
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        
                        Spacer()
                    }
                    
                    // Stats row
                    HStack(spacing: 20) {
                        // Guild reputation
                        HStack(spacing: 4) {
                            Image(systemName: "shield.pattern.checkered")
                                .font(.caption2)
                                .foregroundColor(AppColors.accentColor)
                            Text("\(membership.reputation)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accentColor)
                            Text("reputation")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        
                        // Contribution score
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(membership.contributionScore)%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text("contribution")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                    }
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 12)
            }
            
            Divider()
            
            // Guild Notifications
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Notifications in This Guild")
                
                SettingsToggleRow(
                    icon: "bell.fill",
                    title: "All Notifications",
                    subtitle: "Master toggle for this guild",
                    isOn: $guildNotificationsEnabled,
                    iconColor: AppColors.accentColor
                )
                
                SettingsToggleRow(
                    icon: "megaphone.fill",
                    title: "Announcements",
                    subtitle: "Guild announcements and updates",
                    isOn: $guildAnnouncementsEnabled,
                    iconColor: .orange
                )
                
                SettingsToggleRow(
                    icon: "calendar.badge.clock",
                    title: "Events",
                    subtitle: "Upcoming guild events",
                    isOn: $guildEventsEnabled,
                    iconColor: .blue
                )
                
                SettingsToggleRow(
                    icon: "mappin.circle.fill",
                    title: "Chart Markers",
                    subtitle: "When members add markers",
                    isOn: $guildMarkersEnabled,
                    iconColor: .red
                )
                
                SettingsToggleRow(
                    icon: "message.fill",
                    title: "Chat Messages",
                    subtitle: "Guild chatroom activity",
                    isOn: $guildChatEnabled,
                    iconColor: AppColors.accentColor
                )
                
                SettingsToggleRow(
                    icon: "paperplane.fill",
                    title: "Direct Messages",
                    subtitle: "DMs from guild members",
                    isOn: $guildDMsEnabled,
                    iconColor: .purple
                )
            }
            
            Divider()
            
            // Guild Privacy
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Privacy in This Guild")
                
                SettingsToggleRow(
                    icon: "circle.fill",
                    title: "Show Online Status",
                    subtitle: "Let guild members see when you're online",
                    isOn: $showOnlineStatusInGuild,
                    iconColor: AppColors.bullCandleGreen
                )
                
                SettingsToggleRow(
                    icon: "eye.fill",
                    title: "Show Activity",
                    subtitle: "Let members see your trading activity",
                    isOn: $showActivityInGuild,
                    iconColor: .blue
                )
                
                SettingsToggleRow(
                    icon: "envelope.fill",
                    title: "Allow DMs",
                    subtitle: "Receive direct messages from members",
                    isOn: $allowGuildDMs,
                    iconColor: .purple
                )
            }
            
            Divider()
            
            // Leave Guild
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Guild Actions")
                
                SettingsButtonRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Leave Guild",
                    subtitle: "Remove yourself from \(guild.name)",
                    iconColor: .red
                ) {
                    withAnimation {
                        currentDestination = .leaveGuild
                    }
                }
            }
        }
        
        // Large visual separator between guild and global settings
        VStack(spacing: 0) {
            Divider()
            Rectangle()
                .fill(AppColors.sheetBackground.opacity(0.5))
                .frame(height: 30)
            Divider()
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Global Settings Section
    
    private var globalSettingsSection: some View {
        VStack(spacing: 0) {
            // Global Header
            HStack {
                Image(systemName: "globe")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText.opacity(0.9))
                Text("Global Account Settings")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 10)
            
            // Account & Profile
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Profile")
                
                if let user = rlAppState.currentUser {
                    // User info display
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(String(user.username.prefix(2)).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.accentColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.headline)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "shield.pattern.checkered")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.accentColor)
                                Text("\(user.globalReputation) global reputation")
                                    .font(.caption)
                                    .foregroundColor(AppColors.accentColor)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 12)
                }
                
                SettingsButtonRow(
                    icon: "person.fill",
                    title: "Edit Profile",
                    subtitle: "Name, username, and avatar",
                    iconColor: AppColors.accentColor
                ) {
                    withAnimation {
                        currentDestination = .editProfile
                    }
                }
                
                SettingsButtonRow(
                    icon: "envelope.fill",
                    title: "Email",
                    subtitle: rlAppState.currentUser?.email ?? "Update email address",
                    iconColor: .blue
                ) {
                    withAnimation {
                        currentDestination = .changeEmail
                    }
                }
                
                SettingsButtonRow(
                    icon: "key.fill",
                    title: "Change Password",
                    subtitle: "Update your account password",
                    iconColor: .orange
                ) {
                    withAnimation {
                        currentDestination = .changePassword
                    }
                }
                
                SettingsButtonRow(
                    icon: "calendar.badge.clock",
                    title: "Date of Birth",
                    subtitle: "Update your birth date",
                    iconColor: .purple
                ) {
                    withAnimation {
                        currentDestination = .dateOfBirth
                    }
                }
                
                SettingsButtonRow(
                    icon: "tag.fill",
                    title: "Trading Interests",
                    subtitle: "Topics and markets you follow",
                    iconColor: AppColors.bullCandleGreen
                ) {
                    withAnimation {
                        currentDestination = .tradingInterests
                    }
                }
            }
            
            Divider()
            
            // Global Privacy
            VStack(spacing: 0) {
                SettingsSectionHeader(title: "Privacy & Safety")
                
                SettingsToggleRow(
                    icon: "circle.fill",
                    title: "Show Online Status",
                    subtitle: "Let others see when you're online",
                    isOn: $showGlobalOnlineStatus,
                    iconColor: AppColors.bullCandleGreen
                )
                
                SettingsToggleRow(
                    icon: "person.badge.plus",
                    title: "Allow Friend Requests",
                    subtitle: "Let others send you friend requests",
                    isOn: $allowFriendRequests,
                    iconColor: .blue
                )
                
                SettingsToggleRow(
                    icon: "shield.pattern.checkered",
                    title: "Show Global Reputation",
                    subtitle: "Display reputation on your profile",
                    isOn: $showGlobalReputation,
                    iconColor: AppColors.accentColor
                )
                
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
    
    private func leaveGuild() {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        Task {
            do {
                // try await rlAppState.leaveGuild(guildId: guildId)
                // For now, just show success
                print("Left guild: \(guildId)")
            } catch {
                print("Failed to leave guild: \(error)")
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                // try await rlAppState.deleteUserAccount()
                rlAppState.logout()
                onBack()
            } catch {
                print("Failed to delete account: \(error)")
            }
        }
    }
    
    private func requestAppReview() {
        // This would normally use StoreKit to request a review
        // For now, just print
        print("Requesting app review...")
    }
}


// MARK: - Preview

#Preview {
    UserSettingsSheetView(onBack: {})
        .environmentObject(AppState())
        .environmentObject(RLAppState())
        .preferredColorScheme(.dark)
}










// //
// //  UserSettingsView.swift
// //  traders_guild
// //
// //  Created by Al Hennessey on 12/10/2025.
// //
// import SwiftUI


// struct UserSettingsSheetView: View {
//     @EnvironmentObject var appState: AppState
    
//     @EnvironmentObject var RLAppState: RLAppState
//     let onBack: () -> Void
    
//     @State private var showLogoutConfirmation = false
//     @State private var showLeaveGuildConfirmation = false
//     @State private var showDeleteAccountConfirmation = false
    
//     // Current Guild notification states
//     @State private var guildNotificationsEnabled = true
//     @State private var guildAnnouncementsEnabled = true
//     @State private var guildEventsEnabled = true
//     @State private var guildMarkersEnabled = true
//     @State private var guildChatEnabled = true
//     @State private var guildDMsEnabled = true
    
//     // Current Guild privacy states
//     @State private var showOnlineStatusInGuild = true
//     @State private var showActivityInGuild = true
//     @State private var allowGuildDMs = true
    
//     // Global notification states
//     @State private var globalDMNotifications = true
//     @State private var globalFriendRequests = true
//     @State private var globalGuildInvites = true
//     @State private var emailNotifications = true
    
//     // Global privacy states
//     @State private var showGlobalOnlineStatus = true
//     @State private var allowFriendRequests = true
//     @State private var showGlobalReputation = true
    
//     var hasCurrentGuild: Bool {
//         appState.currentGuild != nil
//     }
    
//     var body: some View {
//         if let user = appState.currentUser,
//            let guild = appState.currentGuild {
//             ZStack {
//                 // Background that extends to safe area
//                 AppColors.sheetBackground
//                     .ignoresSafeArea()
                
//                 ScrollView {
//                     VStack(spacing: 0) {
//                         // Header with Back Button
//                         HStack {
//                             Button(action: onBack) {
//                                 HStack(spacing: 6) {
//                                     Image(systemName: "chevron.left")
//                                         .font(.headline)
//                                     Text("Back")
//                                         .font(.headline)
//                                 }
//                                 .foregroundColor(AppColors.whiteText)
//                             }
                            
//                             Spacer()
                            
//                             Text("Settings")
//                                 .font(.title2)
//                                 .fontWeight(.bold)
//                                 .foregroundColor(AppColors.whiteText)
                            
//                             Spacer()
                            
//                             // Invisible button for balance
//                             HStack(spacing: 6) {
//                                 Image(systemName: "chevron.left")
//                                     .font(.headline)
//                                 Text("Back")
//                                     .font(.headline)
//                             }
//                             .opacity(0)
//                         }
//                         .padding(.horizontal, 25)
//                         .padding(.top, 20)
//                         .padding(.bottom, 10)
                        
//                         // CURRENT GUILD SETTINGS SECTION (if in a guild)
                        
//                         VStack(spacing: 0) {
//                             // Guild Header
//                             HStack {
//                                 Text("\(guild.guild.name) Settings")
//                                     .font(.title3)
//                                     .fontWeight(.bold)
//                                     .foregroundColor(AppColors.whiteText)
//                                 Spacer()
//                             }
//                             .padding(.horizontal, 25)
//                             .padding(.bottom, 10)
                            
//                             // My Guild Membership Info
//                             VStack(spacing: 0) {
//                                 SettingsSectionHeader(title: "My Guild Membership")
                                
//                                 // Membership info display
//                                 VStack(alignment: .leading, spacing: 12) {
//                                     HStack(spacing: 12) {
//                                         ZStack {
//                                             RoundedRectangle(cornerRadius: 8)
//                                                 .fill(AppColors.accentColor.opacity(0.2))
//                                                 .frame(width: 36, height: 36)
//                                             Image(systemName: "person.badge.shield.checkmark.fill")
//                                                 .font(.system(size: 16))
//                                                 .foregroundColor(AppColors.accentColor)
//                                         }
                                        
//                                         VStack(alignment: .leading, spacing: 4) {
//                                             HStack(spacing: 8) {
//                                                 Text("Role:")
//                                                     .font(.subheadline)
//                                                     .foregroundColor(AppColors.greyText)
                                                
//                                                 Text(guild.roleInGuild.rawValue)
//                                                     .font(.subheadline)
//                                                     .fontWeight(guild.roleInGuild.roleFontWeight)
//                                                     .foregroundColor(guild.roleInGuild.roleForegroundColor)
//                                             }
                                            
//                                             Text(guild.memberSince)
//                                                 .font(.caption)
//                                                 .foregroundColor(AppColors.greyText)
//                                         }
                                        
//                                         Spacer()
//                                     }
                                    
//                                     // Stats row
//                                     HStack(spacing: 20) {
//                                         // Guild reputation
//                                         HStack(spacing: 4) {
//                                             Image(systemName: "shield.pattern.checkered")
//                                                 .font(.caption2)
//                                                 .foregroundColor(AppColors.accentColor)
//                                             Text("\(guild.reputation)")
//                                                 .font(.subheadline)
//                                                 .fontWeight(.semibold)
//                                                 .foregroundColor(AppColors.accentColor)
//                                             Text("reputation")
//                                                 .font(.caption)
//                                                 .foregroundColor(AppColors.greyText)
//                                         }
                                        
  
//                                     }
//                                 }
//                                 .padding(.horizontal, 25)
//                                 .padding(.vertical, 12)
//                             }
                            
//                             Divider()
                            
//                             // Guild Notifications
//                             VStack(spacing: 0) {
//                                 SettingsSectionHeader(title: "Notifications in This Guild")
                                
//                                 SettingsToggleRow(
//                                     icon: "bell.fill",
//                                     title: "All Notifications",
//                                     subtitle: "Master toggle for this guild",
//                                     isOn: $guildNotificationsEnabled,
//                                     iconColor: AppColors.accentColor
//                                 )
                                
//                                 SettingsToggleRow(
//                                     icon: "megaphone.fill",
//                                     title: "Announcements",
//                                     subtitle: "Guild announcements and updates",
//                                     isOn: $guildAnnouncementsEnabled,
//                                     iconColor: .orange
//                                 )
                                
//                                 SettingsToggleRow(
//                                     icon: "calendar.badge.clock",
//                                     title: "Events",
//                                     subtitle: "Upcoming guild events",
//                                     isOn: $guildEventsEnabled,
//                                     iconColor: .blue
//                                 )
                                
//                                 SettingsToggleRow(
//                                     icon: "mappin.circle.fill",
//                                     title: "Chart Markers",
//                                     subtitle: "When members add markers",
//                                     isOn: $guildMarkersEnabled,
//                                     iconColor: .red
//                                 )
                                
//                                 SettingsToggleRow(
//                                     icon: "message.fill",
//                                     title: "Chat Messages",
//                                     subtitle: "Guild chatroom activity",
//                                     isOn: $guildChatEnabled,
//                                     iconColor: AppColors.accentColor
//                                 )
                                
//                                 SettingsToggleRow(
//                                     icon: "paperplane.fill",
//                                     title: "Direct Messages",
//                                     subtitle: "DMs from guild members",
//                                     isOn: $guildDMsEnabled,
//                                     iconColor: .purple
//                                 )
//                             }
                            
                            
                            
                            
//                             Divider()
                            
//                             // Leave Guild
//                             VStack(spacing: 0) {
//                                 SettingsSectionHeader(title: "Guild Actions")
                                
//                                 SettingsButtonRow(
//                                     icon: "rectangle.portrait.and.arrow.right",
//                                     title: "Leave Guild",
//                                     subtitle: "Remove yourself from \(guild.guild.name)",
//                                     iconColor: .red
//                                 ) {
//                                     showLeaveGuildConfirmation = true
//                                 }
//                             }
//                         }
                        
//                         // Large visual separator between guild and global settings
//                         VStack(spacing: 0) {
//                             Divider()
//                             Rectangle()
//                                 .fill(AppColors.sheetBackground.opacity(0.5))
//                                 .frame(height: 30)
//                             Divider()
//                         }
//                         .padding(.vertical, 20)
//                     }
                    
//                     // GLOBAL ACCOUNT SETTINGS SECTION
//                     VStack(spacing: 0) {
//                         // Global Header
//                         HStack {
//                             Image(systemName: "globe")
//                                 .font(.title3)
//                                 .fontWeight(.bold)
//                                 .foregroundColor(AppColors.whiteText.opacity(0.9))
//                             Text("Global Account Settings")
//                                 .font(.title3)
//                                 .fontWeight(.bold)
//                                 .foregroundColor(AppColors.whiteText)
//                             Spacer()
//                         }
//                         .padding(.horizontal, 25)
//                         .padding(.bottom, 10)
                        
//                         // Account & Profile
//                         VStack(spacing: 0) {
//                             SettingsSectionHeader(title: "Profile")
                            
//                             if let user = appState.currentUser {
//                                 // User info display
//                                 HStack(spacing: 12) {
//                                     Circle()
//                                         .fill(AppColors.accentColor.opacity(0.3))
//                                         .frame(width: 50, height: 50)
//                                         .overlay(
//                                             Text(String(user.username.prefix(2)))
//                                                 .font(.headline)
//                                                 .fontWeight(.bold)
//                                                 .foregroundColor(AppColors.accentColor)
//                                         )
                                    
//                                     VStack(alignment: .leading, spacing: 4) {
//                                         Text(user.name)
//                                             .font(.headline)
//                                             .foregroundColor(AppColors.whiteText)
                                        
//                                         Text("@\(user.username)")
//                                             .font(.subheadline)
//                                             .foregroundColor(AppColors.greyText)
                                        
//                                         HStack(spacing: 4) {
//                                             Image(systemName: "shield.pattern.checkered")
//                                                 .font(.caption2)
//                                                 .foregroundColor(AppColors.accentColor)
//                                             Text("\(user.globalReputation) global reputation")
//                                                 .font(.caption)
//                                                 .foregroundColor(AppColors.accentColor)
//                                         }
//                                     }
                                    
//                                     Spacer()
//                                 }
//                                 .padding(.horizontal, 25)
//                                 .padding(.vertical, 12)
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "person.fill",
//                                 title: "Edit Profile",
//                                 subtitle: "Name, username, and avatar",
//                                 iconColor: AppColors.accentColor
//                             ) {
//                                 // Navigate to profile edit
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "envelope.fill",
//                                 title: "Email",
//                                 subtitle: appState.currentUser?.email ?? "Update email address",
//                                 iconColor: .blue
//                             ) {
//                                 // Navigate to email change
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "key.fill",
//                                 title: "Change Password",
//                                 subtitle: "Update your account password",
//                                 iconColor: .orange
//                             ) {
//                                 // Navigate to password change
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "calendar.badge.clock",
//                                 title: "Date of Birth",
//                                 subtitle: "Update your birth date",
//                                 iconColor: .purple
//                             ) {
//                                 // Navigate to DOB update
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "tag.fill",
//                                 title: "Trading Interests",
//                                 subtitle: "Topics and markets you follow",
//                                 iconColor: AppColors.bullCandleGreen
//                             ) {
//                                 // Navigate to interests/topics
//                             }
//                         }
                        
//                         Divider()
                        
//                         // Global Privacy
//                         VStack(spacing: 0) {
//                             SettingsSectionHeader(title: "Privacy & Safety")
                            
//                             SettingsToggleRow(
//                                 icon: "circle.fill",
//                                 title: "Show Online Status",
//                                 subtitle: "Let others see when you're online",
//                                 isOn: $showGlobalOnlineStatus,
//                                 iconColor: AppColors.bullCandleGreen
//                             )
                            
//                             SettingsToggleRow(
//                                 icon: "person.badge.plus",
//                                 title: "Allow Friend Requests",
//                                 subtitle: "Let others send you friend requests",
//                                 isOn: $allowFriendRequests,
//                                 iconColor: .blue
//                             )
                            
//                             SettingsToggleRow(
//                                 icon: "shield.pattern.checkered",
//                                 title: "Show Global Reputation",
//                                 subtitle: "Display reputation on your profile",
//                                 isOn: $showGlobalReputation,
//                                 iconColor: AppColors.accentColor
//                             )
                            
//                             SettingsButtonRow(
//                                 icon: "hand.raised.fill",
//                                 title: "Blocked Users",
//                                 subtitle: "Manage blocked accounts",
//                                 iconColor: .red
//                             ) {
//                                 // Navigate to blocked users list
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "eye.slash.fill",
//                                 title: "Data & Privacy",
//                                 subtitle: "Control your data and visibility",
//                                 iconColor: .purple
//                             ) {
//                                 // Navigate to data privacy settings
//                             }
//                         }
                        
         
                        
//                         Divider()
                        
//                         // Appearance & Preferences
//                         VStack(spacing: 0) {
//                             SettingsSectionHeader(title: "Appearance & Preferences")
                            
//                             SettingsButtonRow(
//                                 icon: "paintbrush.fill",
//                                 title: "Theme",
//                                 subtitle: "Light, Semi-Dark, or Dark",
//                                 iconColor: .purple
//                             ) {
//                                 // Navigate to theme selection
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "chart.line.uptrend.xyaxis",
//                                 title: "Default Chart Settings",
//                                 subtitle: "Global chart preferences",
//                                 iconColor: AppColors.bullCandleGreen
//                             ) {
//                                 // Navigate to global chart preferences
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "globe",
//                                 title: "Language & Region",
//                                 subtitle: "App language and regional settings",
//                                 iconColor: .blue
//                             ) {
//                                 // Navigate to language settings
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "textformat.size",
//                                 title: "Display Settings",
//                                 subtitle: "Font size and accessibility",
//                                 iconColor: .orange
//                             ) {
//                                 // Navigate to display settings
//                             }
//                         }
                        
//                         Divider()
                        
                        
//                         // Help & Support
//                         VStack(spacing: 0) {
//                             SettingsSectionHeader(title: "Help & Support")
                            
//                             SettingsButtonRow(
//                                 icon: "questionmark.circle.fill",
//                                 title: "Help Center",
//                                 subtitle: "FAQs and tutorials",
//                                 iconColor: .blue
//                             ) {
//                                 // Navigate to help center
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "envelope.fill",
//                                 title: "Contact Support",
//                                 subtitle: "Get help from our team",
//                                 iconColor: AppColors.accentColor
//                             ) {
//                                 // Navigate to support
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "star.fill",
//                                 title: "Rate the App",
//                                 subtitle: "Share your feedback",
//                                 iconColor: .yellow
//                             ) {
//                                 // Trigger App Store rating
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "doc.text.fill",
//                                 title: "Terms & Privacy",
//                                 subtitle: "Legal information",
//                                 iconColor: .gray
//                             ) {
//                                 // Navigate to legal docs
//                             }
                            
//                             SettingsButtonRow(
//                                 icon: "info.circle.fill",
//                                 title: "About",
//                                 subtitle: "Version and app information",
//                                 iconColor: .purple
//                             ) {
//                                 // Navigate to about page
//                             }
//                         }
                        
//                         Divider()
                        
//                         // Account Management
//                         VStack(spacing: 0) {
//                             SettingsSectionHeader(title: "Account Management")
                            
        
                            
//                             SettingsButtonRow(
//                                 icon: "trash.fill",
//                                 title: "Delete Account",
//                                 subtitle: "Permanently delete your account",
//                                 iconColor: .red
//                             ) {
//                                 showDeleteAccountConfirmation = true
//                             }
//                         }
//                     }
                    
//                     // Logout Section (Always at bottom)
//                     VStack(spacing: 0) {
//                         Divider()
//                         Rectangle()
//                             .fill(AppColors.sheetBackground.opacity(0.5))
//                             .frame(height: 20)
//                         Divider()
                        
//                         Button(action: {
//                             showLogoutConfirmation = true
//                         }) {
//                             HStack {
//                                 Image(systemName: "rectangle.portrait.and.arrow.right")
//                                     .font(.headline)
//                                     .foregroundColor(.red)
//                                     .frame(width: 30)
                                
//                                 Text("Logout")
//                                     .font(.subheadline)
//                                     .fontWeight(.semibold)
//                                     .foregroundColor(.red)
                                
//                                 Spacer()
//                             }
//                             .padding()
//                             .background(Color.red.opacity(0.1))
//                             .cornerRadius(10)
//                             .overlay(
//                                 RoundedRectangle(cornerRadius: 10)
//                                     .stroke(Color.red.opacity(0.3), lineWidth: 1)
//                             )
//                         }
//                         .padding(.horizontal, 25)
//                         .padding(.top, 20)
//                     }
                    
//                     Spacer(minLength: 100)
//                 }
//             }
            
            
//             .alert("Logout", isPresented: $showLogoutConfirmation) {
//                 Button("Cancel", role: .cancel) { }
//                 Button("Logout", role: .destructive) {
//                     RLAppState.logout()
//                     onBack()
//                 }
//             } message: {
//                 Text("Are you sure you want to logout?")
//             }
//             .alert("Leave Guild", isPresented: $showLeaveGuildConfirmation) {
//                 Button("Cancel", role: .cancel) { }
//                 Button("Leave", role: .destructive) {
//                     leaveGuild()
//                 }
//             } message: {
//                 Text("Are you sure you want to leave \(guild.guild.name)? You can rejoin later if it's open.")
//             }
//             .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
//                 Button("Cancel", role: .cancel) { }
//                 Button("Delete", role: .destructive) {
//                     deleteAccount()
//                 }
//             } message: {
//                 Text("Are you sure you want to permanently delete your account? This cannot be undone and all your data will be removed.")
//             }
//         }
//     }
    
//     // MARK: - Actions
    
//     private func leaveGuild() {
//         guard let guildId = appState.currentGuild?.id else { return }
//         Task {
//             do {
//                 //try await appState.leaveGuild(guildId: guildId)
//                 appState.showSuccess("Left guild successfully")
//             } catch {
//                 appState.showError(error, title: "Failed to Leave Guild")
//             }
//         }
//     }
    
//     private func deleteAccount() {
//         Task {
//             do {
//                 //try await appState.deleteUserAccount()
//                 appState.showSuccess("Account deleted successfully")
//                 onBack()
//             } catch {
//                 appState.showError(error, title: "Failed to Delete Account")
//             }
//         }
//     }
// }







// #Preview {
//     UserSettingsSheetView(onBack: {})
//         .environmentObject(AppState())
//         .preferredColorScheme(.dark)
// }
