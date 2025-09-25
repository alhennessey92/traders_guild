//
//  SessionStore.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI
import Combine

// Global session store that tracks if a user is logged in
// Used with @EnvironmentObject in all views that care about login state
class SessionStore: ObservableObject {
    @Published var currentUser: User? // nil if logged out
    @Published var showingTransition: Bool = false
    
    func setUser(_ user: User) {
        self.currentUser = user
        self.showingTransition = true // always show transition when logging in
    }
    
    func clearSession() {
        self.currentUser = nil
        self.showingTransition = false
    }
    
    func finishWelcome() {
        self.showingTransition = false
    }
}
