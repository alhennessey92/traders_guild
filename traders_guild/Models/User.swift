//
//  User.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation

// Represents a logged-in user
// Conforms to Codable for easy JSON parsing from network responses
// Conforms to Identifiable for use in SwiftUI lists if needed
struct User: Codable, Identifiable {
    var id: String       // Unique identifier for the user
    var name: String     // User’s full name
    var email: String    // Email address
//    var token: String    // Authentication token for API requests
}
