//
//  User.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation
import SwiftUI

// MARK: - User roles
enum UserRole: String, Codable {
    case member = "Member"
    case admin = "Admin"
    case moderator = "Moderator"
}

// MARK: - Core User Model (source of truth)
// Represents an account/user in the system
// Conforms to Codable for easy JSON parsing from network responses
// Conforms to Identifiable for use in SwiftUI lists if needed
struct User: Identifiable, Codable, Equatable {
    var id: UUID                 // Unique identifier for the user
    var name: String             // Display name/username
    var email: String            // Email address
    var globalReputation: Int          // Global reputation
    var isOnline: Bool           // Presence
    var status: String?          // Optional user status
    var role: UserRole           // Global role (can differ per guild via GuildMembership)
    
    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        globalReputation: Int = 0,
        isOnline: Bool = false,
        status: String? = nil,
        role: UserRole = .member
        
    ){
        self.id = id
        self.name = name
        self.email = email
        self.globalReputation = globalReputation
        self.isOnline = isOnline
        self.status = status
        self.role = role
        
    }
    
    
}

//extension User {
//    static func friendIDs(for userId: UUID) -> Set<UUID> {
//        UserFriends.friendIDs(for: userId)
//    }
//}




//extension UserFriends {
//    // Get all friend IDs for a specific user
//    static func friendIDs(for userId: UUID) -> Set<UUID> {
//        Set(sampleFriends
//            .filter { $0.userID == userId }
//            .map { $0.friendID })
//    }
//    
//    // Check if two users are friends
//    static func areFriends(userId: UUID, friendId: UUID) -> Bool {
//        sampleFriends.contains {
//            ($0.userID == userId && $0.friendID == friendId) ||
//            ($0.userID == friendId && $0.friendID == userId)
//        }
//    }
//}

// MARK: - UI helpers for UserRole
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

// MARK: - Reusable User IDs
struct UserIDs {
    static let seanPain = UUID()
    static let oldFriend = UUID()
    static let tradeMaster = UUID()
    static let chartWizard = UUID()
    static let bullRunner = UUID()
    static let marketGuru = UUID()
    static let stockHawk = UUID()
    static let sleepyTrader = UUID()
    static let nightOwl = UUID()
    static let quietInvestor = UUID()
    static let currentUser = UUID()
}

// MARK: - SAMPLE DATA
extension User {
    static let sampleUsers: [User] = [
        User(
            id: UserIDs.currentUser,
            name: "Alhennessey92",
            email: "al@example.com",
            globalReputation: 100,
            isOnline: true,
            status: "Active",
            role: .member
        ),
        User(
            id: UserIDs.seanPain,
            name: "SeanPain",
            email: "sean@example.com",
            globalReputation: 50,
            isOnline: true,
            status: "Always online",
            role: .moderator
        ),
        User(
            id: UserIDs.tradeMaster,
            name: "TradeMaster",
            email: "trademaster@example.com",
            globalReputation: 45,
            isOnline: true,
            status: "Trading AAPL",
            role: .member
        ),
        User(
            id: UserIDs.bullRunner,
            name: "BullRunner",
            email: "bullrunner@example.com",
            globalReputation: 52,
            isOnline: true,
            status: nil,
            role: .member
        ),
        User(
            id: UserIDs.stockHawk,
            name: "StockHawk",
            email: "stockhawk@example.com",
            globalReputation: 33,
            isOnline: true,
            status: nil,
            role: .member
        ),
        User(
            id: UserIDs.chartWizard,
            name: "ChartWizard",
            email: "chartwizard@example.com",
            globalReputation: 38,
            isOnline: false,
            status: "Analyzing markets",
            role: .admin
        ),
        User(
            id: UserIDs.marketGuru,
            name: "MarketGuru",
            email: "marketguru@example.com",
            globalReputation: 41,
            isOnline: true,
            status: "In a meeting",
            role: .moderator
        ),
        User(
            id: UserIDs.oldFriend,
            name: "OldFriend",
            email: "oldfriend@example.com",
            globalReputation: 44,
            isOnline: false,
            status: "Busy IRL",
            role: .member
        ),
        User(
            id: UserIDs.nightOwl,
            name: "NightOwl",
            email: "nightowl@example.com",
            globalReputation: 47,
            isOnline: false,
            status: "Away",
            role: .admin
        ),
        User(
            id: UserIDs.sleepyTrader,
            name: "SleepyTrader",
            email: "sleepy@example.com",
            globalReputation: 29,
            isOnline: false,
            status: nil,
            role: .member
        ),
        User(
            id: UserIDs.quietInvestor,
            name: "QuietInvestor",
            email: "quiet@example.com",
            globalReputation: 36,
            isOnline: false,
            status: nil,
            role: .member
        )
    ]
}


