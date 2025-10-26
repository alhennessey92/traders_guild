////
////  traders_guildApp.swift
////  traders_guild
////
////  Created by Al Hennessey on 16/07/2025.
////
///
///
import SwiftUI

@main
struct traders_guildApp: App {
    @StateObject private var messagingManager = MessagingManager()
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.showingTransition {
                    TransitionView()
                        .environmentObject(appState)
                        .environmentObject(messagingManager)
                } else {
                    Group {
                        if appState.isAuthenticated && appState.currentGuild != nil {
                            MainView()
                                .preferredColorScheme(.dark)
                        } else {
                            ContentView()
                        }
                    }
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { appState.errorMessage != nil },
                    set: { if !$0 { appState.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    appState.errorMessage = nil
                }
            } message: {
                if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                }
            }
            // ✅ Change to fullScreenCover instead of sheet
            .fullScreenCover(isPresented: $appState.showGuildSelectionSheet) {
                GuildSelectionFullView()
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
            }
        }
    }
}
//import SwiftUI
//
//@main
//struct traders_guildApp: App {
//    @StateObject private var messagingManager = MessagingManager()
//    @StateObject private var appState = AppState()
//    
//    var body: some Scene {
//        WindowGroup {
//            if appState.showingTransition {
//                // Show transition/loading view
//                TransitionView()
//                    .environmentObject(appState)
//                    .environmentObject(messagingManager)
//            } else {
//                // Show main app content after transition
//                Group {
//                    if appState.isAuthenticated {
//                        MainView()
//                            .preferredColorScheme(.dark)
//                    } else {
//                        ContentView()
//                    }
//                }
//                .environmentObject(appState)
//                .environmentObject(messagingManager)
//            }
//        }
//    }
//}
