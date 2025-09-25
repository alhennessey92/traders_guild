//
//  AuthService.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation
import Combine

// Handles authentication logic for login, signup, logout
// Can be swapped later with real API calls to your backend
class AuthService {
    
    // MARK: - Login
    
    /// Attempts to login with email/password
    /// - Parameters:
    ///   - email: user's email
    ///   - password: user's password
    ///   - completion: closure returning Result<User, Error>
    func login(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Create a mock user object
            let user = User(id: UUID().uuidString, name: "Demo User", email: email)
            completion(.success(user))
        }
    }
    
    // MARK: - Signup
    
    /// Signs up a new user with the collected SignupData
    /// - Parameters:
    ///   - data: SignupData object containing all wizard info
    ///   - completion: closure returning Result<User, Error>
    func signup(data: SignupData, completion: @escaping (Result<User, Error>) -> Void) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let user = User(id: UUID().uuidString, name: data.name, email: data.email)
            completion(.success(user))
        }
    }
    
    // MARK: - Logout
    
    /// Clears the current session
    /// - Parameter session: the global SessionStore object
    func logout(session: SessionStore) {
        session.clearSession()
    }
}
