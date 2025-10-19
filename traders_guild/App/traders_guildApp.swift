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
    @StateObject var currentUser = UserStore()
    @StateObject var messagingManager = MessagingManager() // Add global messaging manager
    
    var body: some Scene {
        WindowGroup {
            Group {
                if session.currentUser == nil {
                    ContentView()
                } else if session.showingTransition {
                    TransitionView()
                } else {
                    MainView()
                        .preferredColorScheme(.dark)
                }
            }
            .environmentObject(session)
            .environmentObject(currentUser)
            .environmentObject(messagingManager) // Provide messaging manager to all views
            .onAppear {
                // TESTING: Auto-login for development - remove this when ready for production
                if session.currentUser == nil {
                    let testUser = User(id: UserIDs.currentUser, name: "Alhennessey92", email: "test@example.com", globalReputation: 100, isOnline: true, role: .member)
                    session.setUser(testUser)
                }
                
                // Keep UserStore in sync with SessionStore at launch
                if let user = session.currentUser {
                    currentUser.login(user: user)
                } else {
                    currentUser.logout()
                }
            }
            .onChange(of: session.currentUser) { oldValue, newValue in
                // Keep UserStore in sync with SessionStore whenever the session user changes
                if let user = newValue {
                    currentUser.login(user: user)
                } else {
                    currentUser.logout()
                }
            }
        }
    }
}

