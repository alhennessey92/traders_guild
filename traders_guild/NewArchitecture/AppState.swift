



//
//  AppState.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//


//
//  AppState.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    
    // ================================================================================================
    // MARK: - Core State
    // ================================================================================================
    
    /// Currently logged-in user
    @Published var currentUser: CurrentUserDTO? {
        didSet {
            isAuthenticated = currentUser != nil
            if let user = currentUser {
                saveUserToKeychain(user)
            } else {
                clearKeychain()
            }
        }
    }
    
    /// Authentication status
    @Published var isAuthenticated: Bool = false
    
    /// JWT authentication token
    @Published var authToken: String? {
        didSet {
            if let token = authToken {
                saveTokenToKeychain(token)
            }
        }
    }
    
    /// Currently selected guild
    @Published var currentGuild: GuildDTO?
    
    // ================================================================================================
    // MARK: - UI State
    // ================================================================================================
    
    /// Loading indicator
    @Published var isLoading: Bool = false
    
    /// Error message for alerts
    @Published var errorMessage: String?
    
    /// Show/hide login sheet
    @Published var showLoginSheet: Bool = false
    
    /// Show transition/loading view on app launch
    @Published var showingTransition: Bool = true

    /// Track if initial load is complete
    @Published var hasCompletedInitialLoad: Bool = false
    
    
    // ================================================================================================
    // MARK: - Services
    // ================================================================================================
    
    private let api = MockAPIService()  // TODO: Replace with real API service
    
    // ================================================================================================
    // MARK: - Initialization
    // ================================================================================================
    
    init() {
        Task {
            await restoreSession()
        }
    }
    
    // ================================================================================================
    // MARK: - Authentication
    // ================================================================================================
    
    /// Signup with email and password
    func signUp(data: SignupData) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // TODO: Replace with real API call
            // let response = try await api.post("/auth/signup", body: ["email": email, "password": password]) FROM DATA
            // self.currentUser = response.user
            // self.authToken = response.token
            
            // Mock implementation
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            self.currentUser = SampleData.currentUser
            self.authToken = "mock-jwt-token"
            
//            showLoginSheet = false
            
        } catch {
            errorMessage = "Signup failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Login with email and password
    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // TODO: Replace with real API call
            // let response = try await api.post("/auth/login", body: ["email": email, "password": password])
            // self.currentUser = response.user
            // self.authToken = response.token
            
            // Mock implementation
            try await Task.sleep(nanoseconds: 1_000_000_000)
            self.currentUser = SampleData.currentUser
            self.authToken = "mock-jwt-token"
            
            showLoginSheet = false
            
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Logout and clear session
    func logout() {
        currentUser = nil
        authToken = nil
        currentGuild = nil
        clearKeychain()
        showLoginSheet = true
    }
    
    /// Restore saved session from storage
    private func restoreSession() async {
        if let savedToken = getTokenFromKeychain(),
           let savedUser = getUserFromKeychain() {
            
            self.authToken = savedToken
            self.currentUser = savedUser
            
            // TODO: Validate token with backend
            
        } else {
            showLoginSheet = true
        }
        // Mark initial load as complete
        hasCompletedInitialLoad = true
    }
    
    // ================================================================================================
    // MARK: - Transition Management
    // ================================================================================================

   /// Called when the transition/welcome animation completes
    func finishTransition() {
        showingTransition = false
    }
    
    // ================================================================================================
    // MARK: - Guild Management
    // ================================================================================================
    
    /// Switch to a different guild
    func selectGuild(_ guild: GuildDTO) {
        currentGuild = guild
    }
    
    // ================================================================================================
    // MARK: - Persistence
    // ================================================================================================
    
    private func saveTokenToKeychain(_ token: String) {
        UserDefaults.standard.set(token, forKey: "authToken")
    }
    
    private func getTokenFromKeychain() -> String? {
        UserDefaults.standard.string(forKey: "authToken")
    }
    
    private func saveUserToKeychain(_ user: CurrentUserDTO) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }
    
    private func getUserFromKeychain() -> CurrentUserDTO? {
        guard let data = UserDefaults.standard.data(forKey: "currentUser") else { return nil }
        return try? JSONDecoder().decode(CurrentUserDTO.self, from: data)
    }
    
    private func clearKeychain() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
}



