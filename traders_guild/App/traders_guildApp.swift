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
            if appState.showingTransition {
                // Show transition/loading view
                TransitionView()
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
            } else {
                // Show main app content after transition
                Group {
                    if appState.isAuthenticated {
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
    }
}
