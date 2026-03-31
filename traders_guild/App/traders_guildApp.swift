//
//  traders_guildApp.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/07/2025.
//
//  UPDATED: Added RLMessagingManager for chatroom/DM system
//

import SwiftUI

// MARK: - Global Keyboard Dismissal

private struct DismissKeyboardOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.background(DismissKeyboardOnTap())
    }
}

@main
struct traders_guildApp: App {
    
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
        
        _rlAppState = StateObject(wrappedValue: rlAppState)
        _rlMessagingManager = StateObject(wrappedValue: rlMessagingManager)
    }
    
    var body: some Scene {
        WindowGroup {
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
            .dismissKeyboardOnTap()
            .animation(.easeOut(duration: 0.5), value: rlAppState.showingTransition)

            // Blocking alerts
            .alert(
                rlAppState.currentAlert?.title ?? "Alert",
                isPresented: Binding(
                    get: { rlAppState.currentAlert?.style == .alert },
                    set: { if !$0 { rlAppState.clearAlert() } }
                )
            ) {
                Button("OK", role: .cancel) {
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
        let _ = print("📱 mainContent: isAuthenticated=\(rlAppState.isAuthenticated), currentGuild=\(rlAppState.currentGuild?.name ?? "nil"), showSheet=\(rlAppState.showGuildSelectionSheet)")

        // Keep login/signup and authenticated-onboarding in the same branch so
        // ContentView identity is stable while auth state flips during signup.
        if !rlAppState.isAuthenticated || rlAppState.isOnboardingFlowActive {
            let _ = print("📱 → Showing ContentView (\(rlAppState.isOnboardingFlowActive ? "onboarding active" : "login"))")
            ContentView()
        } else if rlAppState.currentGuild != nil {
            // Fully authenticated with guild selected
            let _ = print("📱 → Showing MainView")
            MainView()
                .preferredColorScheme(ThemeManager.shared.currentTheme.colorScheme)
                .id(ThemeManager.shared.currentTheme)
                
        } else {
            // Authenticated but no guild selected - show loading/waiting view
            let _ = print("📱 → Showing Loading View")
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Loading your guilds...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.gradientBackgroundDark.opacity(0.9))
            .onAppear {
                // FIXED: Check ALL conditions before calling openGuildSelector
                // This prevents race conditions during login flow
                guard !rlAppState.isCompletingSignup else {
                    print("⏳ Skipping openGuildSelector - completing signup")
                    return
                }
                guard !rlAppState.isHandlingAuthFlow else {
                    print("⏳ Skipping openGuildSelector - auth flow in progress")
                    return
                }
                guard !rlAppState.showGuildSelectionSheet else {
                    print("⏳ Skipping openGuildSelector - sheet already showing")
                    return
                }
                
                // Only trigger if we're NOT in the middle of auth
                // This handles the case of returning to app with saved session but no guild
                Task {
                    await rlAppState.openGuildSelector()
                }
            }
        }
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
