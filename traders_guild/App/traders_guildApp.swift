//
//  traders_guildApp.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/07/2025.
//


import SwiftUI

@main
struct traders_guildApp: App {
    // SessionStore is our global state object that keeps track of the logged-in user.
    // Using @StateObject ensures it lives for the lifetime of the app and is observable by all child views.
    @StateObject var session = SessionStore()
    
    var body: some Scene {
        WindowGroup {
            if session.currentUser == nil {
                ContentView()
                    .environmentObject(session)
            } else if session.showingTransition {
                TransitionView()
                    .environmentObject(session)
            } else {
                RootView()
                    .environmentObject(session)
            }
        }
    }
}
