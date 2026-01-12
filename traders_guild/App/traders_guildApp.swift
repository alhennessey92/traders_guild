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
    
    @StateObject private var rlAppState = RLAppState()
    
    
    @StateObject private var messagingManager = MessagingManager()
    @StateObject private var appState = AppState()
    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
    init() {
        let rlAppState = RLAppState()
        
        let appState = AppState() //TODO: Remove
        let messagingManager = MessagingManager()
        
        // ✅ Configure the connection
        messagingManager.configure(with: appState)
        
        _rlAppState = StateObject(wrappedValue: rlAppState)
        
        _appState = StateObject(wrappedValue: appState) //TODO: Remove
        _messagingManager = StateObject(wrappedValue: messagingManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // ✅ CHANGED: MainContent loads in background (not in if/else)
                // This allows chart to initialize while transition shows
                mainContent
                    .environmentObject(rlAppState)
                
                    .environmentObject(appState) //TODO: remove
                    .environmentObject(messagingManager)
                
                // ✅ TransitionView overlays on top until chart is ready
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
            
            // ✅ Keep blocking alerts - these still use currentAlert
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
        if rlAppState.isAuthenticated && rlAppState.currentGuild != nil {
            MainView()
                .preferredColorScheme(.dark)
                
        } else if rlAppState.isAuthenticated {
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
                if !rlAppState.isCompletingSignup && !rlAppState.showGuildSelectionSheet {
                    Task {
                        await rlAppState.openGuildSelector()
                    }
                }
            }
        } else {
            ContentView()
        }
    }
}


