//
//  User.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation
import SwiftUI




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


// MARK: - User Friends Model
struct UserFriends: Identifiable, Codable, Equatable {
    var id: UUID
    var friendID: UUID
    var dateFriendAdded: Date
    
    init(
        id: UUID = UUID(),
        friendID: UUID,
        dateFriendAdded: Date = Date()
    ) {
        self.id = id
        self.friendID = friendID
        self.dateFriendAdded = dateFriendAdded
    }
}



extension UserFriends {
    static let sampleFriends: [UserFriends] = [
        UserFriends(
            friendID: UserIDs.seanPain,
            dateFriendAdded: Date().addingTimeInterval(-86400 * 30) // 30 days ago
        ),
        UserFriends(
            friendID: UserIDs.oldFriend,
            dateFriendAdded: Date().addingTimeInterval(-86400 * 60) // 60 days ago
        ),
        UserFriends(
            friendID: UserIDs.tradeMaster,
            dateFriendAdded: Date().addingTimeInterval(-86400 * 15) // 15 days ago
        ),
        UserFriends(
            friendID: UserIDs.bullRunner,
            dateFriendAdded: Date().addingTimeInterval(-86400 * 7) // 7 days ago
        ),
        UserFriends(
            friendID: UserIDs.stockHawk,
            dateFriendAdded: Date().addingTimeInterval(-86400 * 3) // 3 days ago
        ),
        UserFriends(
            friendID: UserIDs.nightOwl,
            dateFriendAdded: Date().addingTimeInterval(-86400 * 45) // 45 days ago
        )
    ]
}




