//
//  traders_guildApp.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/07/2025.
//
//  UPDATED: Added RLMessagingManager for chatroom/DM system
//

import SwiftUI

@main
struct traders_guildApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var rlAppState = RLAppState()
    @StateObject private var themeManager = ThemeManager.shared

    // NEW: RL Messaging Manager for chatrooms and DMs (uses RLAppState)
    @StateObject private var rlMessagingManager = RLMessagingManager()
    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
    init() {
        let rlAppState = RLAppState()
        let rlMessagingManager = RLMessagingManager()

        // Configure the connections
        rlMessagingManager.configure(with: rlAppState)       // RL system - chatrooms/DMs
        PushNotificationManager.shared.configure(apiService: rlAppState.realApi)

        // App Store review prompt — fires after the user has placed a
        // meaningful number of markers (see ReviewPromptManager).
        ReviewPromptManager.shared.start()

        _rlAppState = StateObject(wrappedValue: rlAppState)
        _rlMessagingManager = StateObject(wrappedValue: rlMessagingManager)
    }
    
    var body: some Scene {
        WindowGroup {
            let _ = themeManager.currentTheme
            let isBiometricLocked = rlAppState.shouldPresentBiometricAppLock
            ZStack {
                ZStack {
                    // MainContent loads in background (not in if/else)
                    // This allows chart to initialize while transition shows
                    mainContent
                        .environmentObject(rlAppState)
                        .environmentObject(rlMessagingManager)    // chatrooms/DMs

                    // TransitionView overlays on top until chart is ready
                    if rlAppState.showingTransition {
                        TransitionView()
                            .environmentObject(rlAppState)
                            .environmentObject(rlMessagingManager)
                            .transition(.opacity)
                            .zIndex(1) // Ensure it's on top
                    }
                }
                .compositingGroup()
                .blur(radius: isBiometricLocked ? 28 : 0)
                .scaleEffect(isBiometricLocked ? 1.02 : 1)
                .overlay {
                    if isBiometricLocked {
                        ZStack {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                            Color.black.opacity(0.46)
                        }
                        .ignoresSafeArea()
                        .transition(.opacity)
                    }
                }
                .allowsHitTesting(!isBiometricLocked)

                if isBiometricLocked {
                    BiometricAppLockView()
                        .environmentObject(rlAppState)
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .dismissKeyboardOnTapBackground()
            .animation(.easeOut(duration: 0.5), value: rlAppState.showingTransition)
            .animation(.easeInOut(duration: 0.2), value: rlAppState.shouldPresentBiometricAppLock)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    rlAppState.handleSceneDidBecomeActive()
                    if rlAppState.currentUser != nil {
                        Task {
                            await PushNotificationManager.shared.requestPermissionAndRegister(reason: .appActive)
                        }
                    }
                case .inactive:
                    break
                case .background:
                    rlAppState.handleSceneDidEnterBackground()
                @unknown default:
                    break
                }
            }

            // Blocking alerts
            .alert(
                rlAppState.currentAlert?.title ?? "Alert",
                isPresented: Binding(
                    get: { rlAppState.currentAlert?.style == .alert },
                    set: { if !$0 { rlAppState.clearAlert() } }
                )
            ) {
                Button(RLUserFacingCopy.text(.actionOk), role: .cancel) {
                    rlAppState.clearAlert()
                }
            } message: {
                if let alert = rlAppState.currentAlert {
                    Text(alert.message)
                }
            }
            
            // Guild selection sheet - ONLY controlled by rlAppState
            .fullScreenCover(isPresented: $rlAppState.showGuildSelectionSheet) {
                GuildSelectionFullView()
                    .environmentObject(rlAppState)
                    .environmentObject(rlMessagingManager)
            }
            // Biometric enrollment sheet
            .sheet(isPresented: $rlAppState.showBiometricEnrollment) {
                BiometricEnrollmentView()
                    .environmentObject(rlAppState)
            }
            .fullScreenCover(isPresented: $rlAppState.showBetaWelcomeSheet) {
                BetaWelcomeSheetView()
                    .environmentObject(rlAppState)
            }
            .task(id: rlAppState.isAuthenticated) {
                guard rlAppState.isAuthenticated else { return }
                await rlAppState.refreshRuntimeFlags()
            }
            .task(id: rlAppState.pendingEmailVerificationToken) {
                guard let token = rlAppState.pendingEmailVerificationToken,
                      !token.isEmpty else {
                    return
                }
                await rlAppState.consumePendingEmailVerificationToken()
            }
            .onOpenURL { url in
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                let path = components.path.lowercased()
                let host = (components.host ?? "").lowercased()
                let fullRoute = "\(host)\(path)"

                // Handle password reset deep link
                let matchesResetPath = fullRoute.contains("reset-password") || fullRoute.contains("password/reset")
                if matchesResetPath {
                    if let token = components.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value,
                       !token.isEmpty {
                        rlAppState.setPendingPasswordResetToken(token)
                    }
                    return
                }

                // Handle email verification deep link
                let matchesVerifyPath = fullRoute.contains("verify-email") || fullRoute.contains("email/verify")
                if matchesVerifyPath {
                    if let token = components.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value,
                       !token.isEmpty {
                        rlAppState.setPendingEmailVerificationToken(token)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        #if DEBUG
        let _ = print("📱 mainContent: isAuthenticated=\(rlAppState.isAuthenticated), currentGuild=\(rlAppState.currentGuild?.name ?? "nil"), showSheet=\(rlAppState.showGuildSelectionSheet)")
        #endif

        // Keep login/signup and authenticated-onboarding in the same branch so
        // ContentView identity is stable while auth state flips during signup.
        if !rlAppState.isAuthenticated || rlAppState.isOnboardingFlowActive {
            #if DEBUG
            let _ = print("📱 → Showing ContentView (\(rlAppState.isOnboardingFlowActive ? "onboarding active" : "login"))")
            #endif
            ContentView()
        } else if rlAppState.currentGuild != nil {
            // Fully authenticated with guild selected
            #if DEBUG
            let _ = print("📱 → Showing MainView")
            #endif
            MainView()
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
                .id(themeManager.currentTheme)

        } else {
            // Authenticated but no guild selected - show loading/waiting view
            #if DEBUG
            let _ = print("📱 → Showing Loading View")
            #endif
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(AppColors.primaryForeground)
                
                Text("Loading your guilds...")
                    .font(.subheadline)
                    .foregroundColor(AppColors.primaryForeground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.gradientBackgroundDark.opacity(0.9))
            .task(id: rlAppState.isSessionRestored) {
                await openGuildSelectorAfterSessionRestoreIfNeeded()
            }
        }
    }

    @MainActor
    private func openGuildSelectorAfterSessionRestoreIfNeeded() async {
        guard rlAppState.isSessionRestored else {
            #if DEBUG
            print("⏳ Skipping openGuildSelector - session restore still running")
            #endif
            return
        }
        guard rlAppState.isAuthenticated, rlAppState.currentGuild == nil else { return }
        guard !rlAppState.isOnboardingFlowActive else { return }
        guard !rlAppState.isCompletingSignup else {
            #if DEBUG
            print("⏳ Skipping openGuildSelector - completing signup")
            #endif
            return
        }
        guard !rlAppState.isHandlingAuthFlow else {
            #if DEBUG
            print("⏳ Skipping openGuildSelector - auth flow in progress")
            #endif
            return
        }
        guard !rlAppState.showGuildSelectionSheet else {
            #if DEBUG
            print("⏳ Skipping openGuildSelector - sheet already showing")
            #endif
            return
        }

        await rlAppState.openGuildSelector()
    }
}


// //
// //  traders_guildApp.swift
// //  traders_guild
// //
// //  Created by Al Hennessey on 16/07/2025.
// //

// import SwiftUI

// @main
// struct traders_guildApp: App {
    
//     @StateObject private var rlAppState = RLAppState()
    
//     @StateObject private var messagingManager = MessagingManager()
//     @StateObject private var appState = AppState() // TODO: Remove when migration complete
//     @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
//     init() {
//         let rlAppState = RLAppState()
//         let appState = AppState() // TODO: Remove
//         let messagingManager = MessagingManager()
        
//         // Configure the connection
//         messagingManager.configure(with: appState)
        
//         _rlAppState = StateObject(wrappedValue: rlAppState)
//         _appState = StateObject(wrappedValue: appState) // TODO: Remove
//         _messagingManager = StateObject(wrappedValue: messagingManager)
//     }
    
//     var body: some Scene {
//         WindowGroup {
//             ZStack {
//                 // MainContent loads in background (not in if/else)
//                 // This allows chart to initialize while transition shows
//                 mainContent
//                     .environmentObject(rlAppState)
//                     .environmentObject(appState) // TODO: remove
//                     .environmentObject(messagingManager)
                
//                 // TransitionView overlays on top until chart is ready
//                 if rlAppState.showingTransition {
//                     TransitionView()
//                         .environmentObject(rlAppState)
//                         .environmentObject(appState) // TODO: remove
//                         .environmentObject(messagingManager)
//                         .transition(.opacity)
//                         .zIndex(1) // Ensure it's on top
//                 }
//             }
//             .animation(.easeOut(duration: 0.5), value: rlAppState.showingTransition)
            
//             // Blocking alerts
//             .alert(
//                 rlAppState.currentAlert?.title ?? "Alert",
//                 isPresented: Binding(
//                     get: { rlAppState.currentAlert?.style == .alert },
//                     set: { if !$0 { rlAppState.clearAlert() } }
//                 )
//             ) {
//                 Button("OK", role: .cancel) {
//                     rlAppState.clearAlert()
//                 }
//             } message: {
//                 if let alert = rlAppState.currentAlert {
//                     Text(alert.message)
//                 }
//             }
            
//             // Guild selection sheet - ONLY controlled by rlAppState
//             .fullScreenCover(isPresented: $rlAppState.showGuildSelectionSheet) {
//                 GuildSelectionFullView()
//                     .environmentObject(rlAppState)
//                     .environmentObject(appState) // TODO: remove
//                     .environmentObject(messagingManager)
//             }
//         }
//     }
    
//     @ViewBuilder
//     private var mainContent: some View {
//         let _ = print("📱 mainContent: isAuthenticated=\(rlAppState.isAuthenticated), currentGuild=\(rlAppState.currentGuild?.name ?? "nil"), showSheet=\(rlAppState.showGuildSelectionSheet)")
        
//         if rlAppState.isAuthenticated && rlAppState.currentGuild != nil {
//             // Fully authenticated with guild selected
//             let _ = print("📱 → Showing MainView")
//             MainView()
//                 .preferredColorScheme(.dark)
                
//         } else if rlAppState.isAuthenticated {
//             // Authenticated but no guild selected - show loading/waiting view
//             let _ = print("📱 → Showing Loading View")
//             VStack(spacing: 20) {
//                 ProgressView()
//                     .scaleEffect(1.5)
//                     .tint(.white)
                
//                 Text("Loading your guilds...")
//                     .font(.subheadline)
//                     .foregroundColor(.white)
//             }
//             .frame(maxWidth: .infinity, maxHeight: .infinity)
//             .background(AppColors.gradientBackgroundDark.opacity(0.9))
//             .onAppear {
//                 // FIXED: Check ALL conditions before calling openGuildSelector
//                 // This prevents race conditions during login flow
//                 guard !rlAppState.isCompletingSignup else {
//                     print("⏳ Skipping openGuildSelector - completing signup")
//                     return
//                 }
//                 guard !rlAppState.isHandlingAuthFlow else {
//                     print("⏳ Skipping openGuildSelector - auth flow in progress")
//                     return
//                 }
//                 guard !rlAppState.showGuildSelectionSheet else {
//                     print("⏳ Skipping openGuildSelector - sheet already showing")
//                     return
//                 }
                
//                 // Only trigger if we're NOT in the middle of auth
//                 // This handles the case of returning to app with saved session but no guild
//                 Task {
//                     await rlAppState.openGuildSelector()
//                 }
//             }
//         } else {
//             // Not authenticated - show login/signup
//             let _ = print("📱 → Showing ContentView (login)")
//             ContentView()
//         }
//     }
// }
