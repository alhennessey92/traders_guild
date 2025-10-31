////
////  traders_guildApp.swift
////  traders_guild
////
////  Created by Al Hennessey on 16/07/2025.
////
///


import SwiftUI

@main
struct traders_guildApp: App {
    @StateObject private var messagingManager = MessagingManager()
    @StateObject private var appState = AppState()
    
    init() {
        let appState = AppState()
        let messagingManager = MessagingManager()
        
        // ✅ Configure the connection
        messagingManager.configure(with: appState)
        
        _appState = StateObject(wrappedValue: appState)
        _messagingManager = StateObject(wrappedValue: messagingManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.showingTransition {
                    TransitionView()
                        .environmentObject(appState)
                        .environmentObject(messagingManager)
                } else {
                    mainContent
                        .environmentObject(appState)
                        .environmentObject(messagingManager)
                }
                // ❌ REMOVED - ToastWindowManager handles toasts now!
            }
            // ✅ Keep blocking alerts - these still use currentAlert
            .alert(
                appState.currentAlert?.title ?? "Alert",
                isPresented: Binding(
                    get: { appState.currentAlert?.style == .alert },
                    set: { if !$0 { appState.clearAlert() } }
                )
            ) {
                Button("OK", role: .cancel) {
                    appState.clearAlert()
                }
            } message: {
                if let alert = appState.currentAlert {
                    Text(alert.message)
                }
            }
            .fullScreenCover(isPresented: $appState.showGuildSelectionSheet) {
                GuildSelectionFullView()
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
                    // ❌ REMOVED .withGlobalAlerts()
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if appState.isAuthenticated && appState.currentGuild != nil {
            MainView()
                .preferredColorScheme(.dark)
                // ❌ REMOVED .withGlobalAlerts()
                
        } else if appState.isAuthenticated {
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
            // ❌ REMOVED .withGlobalAlerts()
            .onAppear {
                if !appState.isCompletingSignup && !appState.showGuildSelectionSheet {
                    Task {
                        await appState.openGuildSelector()
                    }
                }
            }
        } else {
            ContentView()
            // ❌ REMOVED .withGlobalAlerts()
        }
    }
}

