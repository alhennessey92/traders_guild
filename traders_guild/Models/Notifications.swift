//
//  Notifications.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//

import Foundation


// MARK: - Notification Type
enum NotificationType: String, Codable {
    case personal = "Personal"
    case symbol = "Symbol"
    
}


struct Notification: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let category: NotificationType
    let addedDate: Date
    let userId: UUID
    
    
    init(
        id: UUID = UUID(),
        title: String,
        category: NotificationType,
        addedDate: Date = Date(),
        userId: UUID
        
        
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.addedDate = addedDate
        self.userId = userId
        
    }
}

struct NotificationIDs {
    static let not1 = UUID()
    static let not2 = UUID()
    static let not3 = UUID()

}


// Notifications
extension Notification {
    static let sampleNotifications: [Notification] = [
        Notification(
            id: NotificationIDs.not1,
            title: "Rising EURUSD bet to look",
            category: .symbol,
            addedDate: Date().addingTimeInterval(-3600),
            userId: UserIDs.seanPain
        ),
        
        Notification(
            id: NotificationIDs.not2,
            title: "Youve been promoted to Pro",
            category: .personal,
            addedDate: Date().addingTimeInterval(-3600),
            userId: UserIDs.nightOwl
        ),
        
        Notification(
            id: NotificationIDs.not3,
            title: "Rising audusdfjasd bet to look",
            category: .symbol,
            addedDate: Date().addingTimeInterval(-3600),
            userId: UserIDs.seanPain
        )
        
        
    ]
}
