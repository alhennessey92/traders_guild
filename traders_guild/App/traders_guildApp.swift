////
////  traders_guildApp.swift
////  traders_guild
////
////  Created by Al Hennessey on 16/07/2025.
////
///
///
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
                    // ✅ Remove Group, put logic directly in ZStack
                    mainContent
                        .environmentObject(appState)
                        .environmentObject(messagingManager)
                }
                // ✅ Global Toast Display (non-blocking)
                if let alert = appState.currentAlert, alert.style == .toast {
                    VStack {
                        Spacer()
                        ErrorToastView(alert: alert, onDismiss: {
                            appState.clearAlert()
                        })
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(), value: appState.currentAlert?.id)
                }
            }
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
//            .alert(
//                "Error",
//                isPresented: Binding(
//                    get: { appState.errorMessage != nil },
//                    set: { if !$0 { appState.errorMessage = nil } }
//                )
//            ) {
//                Button("OK", role: .cancel) {
//                    appState.errorMessage = nil
//                }
//            } message: {
//                if let errorMessage = appState.errorMessage {
//                    Text(errorMessage)
//                }
//            }
            .fullScreenCover(isPresented: $appState.showGuildSelectionSheet) {
                GuildSelectionFullView()
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
                    .withGlobalAlerts()
            }
        }
    }
    
    // ✅ Extract to computed property
    @ViewBuilder
    private var mainContent: some View {
        if appState.isAuthenticated && appState.currentGuild != nil {
            // State 1: User + Guild = Show main app
            MainView()
                .preferredColorScheme(.dark)
                .withGlobalAlerts()
                
        } else if appState.isAuthenticated {
            // State 2: User but no guild = Show loading + trigger selector
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
            .withGlobalAlerts()
            .onAppear {
                // ✅ Don't trigger during signup completion
                if !appState.isCompletingSignup && !appState.showGuildSelectionSheet {
                    Task {
                        await appState.openGuildSelector()
                    }
                }
            }
        } else {
            // State 3: No user = Show auth flow
            ContentView()
            .withGlobalAlerts()
        }
    }
}

