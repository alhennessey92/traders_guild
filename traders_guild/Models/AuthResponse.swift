//
//  AuthResponse.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation

// Model to represent a typical response from login/signup endpoints
struct AuthResponse: Codable {
    let user: User       // The user object returned by the backend
    let token: String    // The auth token returned by backend
}
