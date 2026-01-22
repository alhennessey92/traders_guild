//
//  traders_guildApp.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/07/2025.
//

import SwiftUI

@main
struct traders_guildApp: App {
    
    @StateObject private var rlAppState = RLAppState()
    
    @StateObject private var messagingManager = MessagingManager()
    @StateObject private var appState = AppState() // TODO: Remove when migration complete
    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
    init() {
        let rlAppState = RLAppState()
        let appState = AppState() // TODO: Remove
        let messagingManager = MessagingManager()
        
        // Configure the connection
        messagingManager.configure(with: appState)
        
        _rlAppState = StateObject(wrappedValue: rlAppState)
        _appState = StateObject(wrappedValue: appState) // TODO: Remove
        _messagingManager = StateObject(wrappedValue: messagingManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // MainContent loads in background (not in if/else)
                // This allows chart to initialize while transition shows
                mainContent
                    .environmentObject(rlAppState)
                    .environmentObject(appState) // TODO: remove
                    .environmentObject(messagingManager)
                
                // TransitionView overlays on top until chart is ready
                if rlAppState.showingTransition {
                    TransitionView()
                        .environmentObject(rlAppState)
                        .environmentObject(appState) // TODO: remove
                        .environmentObject(messagingManager)
                        .transition(.opacity)
                        .zIndex(1) // Ensure it's on top
                }
            }
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
                    .environmentObject(appState) // TODO: remove
                    .environmentObject(messagingManager)
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        let _ = print("📱 mainContent: isAuthenticated=\(rlAppState.isAuthenticated), currentGuild=\(rlAppState.currentGuild?.name ?? "nil"), showSheet=\(rlAppState.showGuildSelectionSheet)")
        
        if rlAppState.isAuthenticated && rlAppState.currentGuild != nil {
            // Fully authenticated with guild selected
            let _ = print("📱 → Showing MainView")
            MainView()
                .preferredColorScheme(.dark)
                
        } else if rlAppState.isAuthenticated {
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
        } else {
            // Not authenticated - show login/signup
            let _ = print("📱 → Showing ContentView (login)")
            ContentView()
        }
    }
}


