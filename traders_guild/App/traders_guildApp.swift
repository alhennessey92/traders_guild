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
    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
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
                // ✅ CHANGED: MainContent loads in background (not in if/else)
                // This allows chart to initialize while transition shows
                mainContent
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
                
                // ✅ TransitionView overlays on top until chart is ready
                if appState.showingTransition {
                    TransitionView()
                        .environmentObject(appState)
                        .environmentObject(messagingManager)
                        .transition(.opacity)
                        .zIndex(1) // Ensure it's on top
                }
            }
            .animation(.easeOut(duration: 0.5), value: appState.showingTransition)
            
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
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if appState.isAuthenticated && appState.currentGuild != nil {
            MainView()
                .preferredColorScheme(.dark)
                
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
           
            .onAppear {
                if !appState.isCompletingSignup && !appState.showGuildSelectionSheet {
                    Task {
                        await appState.openGuildSelector()
                    }
                }
            }
        } else {
            ContentView()
        }
    }
}



//////
//////  traders_guildApp.swift
//////  traders_guild
//////
//////  Created by Al Hennessey on 16/07/2025.
//////
/////
//
//
//import SwiftUI
//
//@main
//struct traders_guildApp: App {
//    @StateObject private var messagingManager = MessagingManager()
//    @StateObject private var appState = AppState()
//    @StateObject private var notificationNavigationManager = NotificationNavigationManager() // NEW
//    
//    init() {
//        let appState = AppState()
//        let messagingManager = MessagingManager()
//        
//        
//        // ✅ Configure the connection
//        messagingManager.configure(with: appState)
//        
//        
//        
//        _appState = StateObject(wrappedValue: appState)
//        _messagingManager = StateObject(wrappedValue: messagingManager)
//        
//    }
//    
//    var body: some Scene {
//        WindowGroup {
//            ZStack {
//                if appState.showingTransition {
//                    TransitionView()
//                        .environmentObject(appState)
//                        .environmentObject(messagingManager)
//                       
//                } else {
//                    mainContent
//                        .environmentObject(appState)
//                        .environmentObject(messagingManager)
//                        
//                }
//                
//            }
//            // ✅ Keep blocking alerts - these still use currentAlert
//            .alert(
//                appState.currentAlert?.title ?? "Alert",
//                isPresented: Binding(
//                    get: { appState.currentAlert?.style == .alert },
//                    set: { if !$0 { appState.clearAlert() } }
//                )
//            ) {
//                Button("OK", role: .cancel) {
//                    appState.clearAlert()
//                }
//            } message: {
//                if let alert = appState.currentAlert {
//                    Text(alert.message)
//                }
//            }
//            .fullScreenCover(isPresented: $appState.showGuildSelectionSheet) {
//                GuildSelectionFullView()
//                    .environmentObject(appState)
//                    .environmentObject(messagingManager)
//                   
//                    
//            }
//        }
//    }
//    
//    @ViewBuilder
//    private var mainContent: some View {
//        if appState.isAuthenticated && appState.currentGuild != nil {
//            MainView()
//                .preferredColorScheme(.dark)
//                
//                
//        } else if appState.isAuthenticated {
//            VStack(spacing: 20) {
//                ProgressView()
//                    .scaleEffect(1.5)
//                    .tint(.white)
//                
//                Text("Loading your guilds...")
//                    .font(.subheadline)
//                    .foregroundColor(.white)
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(AppColors.gradientBackgroundDark.opacity(0.9))
//           
//            .onAppear {
//                if !appState.isCompletingSignup && !appState.showGuildSelectionSheet {
//                    Task {
//                        await appState.openGuildSelector()
//                    }
//                }
//            }
//        } else {
//            ContentView()
//        }
//    }
//}

