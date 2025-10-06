//
//  User.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation
import SwiftUI


enum UserRole: String, Codable {
    case member = "Member"
    case admin = "Admin"
    case moderator = "Moderator"
}

// MARK: - UserRole UI Extensions
extension UserRole {
    var foregroundColor: Color {
        switch self {
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return AppColors.whiteText.opacity(0.7)
        }
    }
    
    var fontWeight: Font.Weight {
        switch self {
        case .admin: return .bold
        case .moderator: return .bold
        case .member: return .regular
        }
    }
}



// Represents a logged-in user
// Conforms to Codable for easy JSON parsing from network responses
// Conforms to Identifiable for use in SwiftUI lists if needed
struct User: Identifiable, Codable, Equatable {
    var id = UUID()       // Unique identifier for the user
    var name: String     // User’s full name
    var email: String    // Email address
    let reputation: Int
    let isOnline: Bool
    let role: UserRole
//    var token: String    // Authentication token for API requests
}




// MARK: - User Model
struct GuildUser: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let reputation: Int
    let isOnline: Bool
    let isFriend: Bool
    let status: String?
    let role: UserRole
    let newMessage: Bool
}

