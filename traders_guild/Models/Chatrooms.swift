//
//  GuildUser.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//
import Foundation


// MARK: - Chatroom Model
struct Chatroom: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let memberCount: Int
    let isActive: Bool
    let lastMessage: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        memberCount: Int,
        isActive: Bool,
        lastMessage: String?
    ) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.isActive = isActive
        self.lastMessage = lastMessage
    }
}


// CHATROOM
extension Chatroom {
    static let sampleChatrooms: [Chatroom] = [
        
        Chatroom(name: "General Discussion", memberCount: 42, isActive: true, lastMessage: "Great analysis on BTC!"),
        Chatroom(name: "Trading Talk", memberCount: 28, isActive: true, lastMessage: "AAPL looking bullish"),
        Chatroom(name: "Market Analysis", memberCount: 15, isActive: false, lastMessage: "Chart patterns forming"),
        Chatroom(name: "Off Topic", memberCount: 8, isActive: false, lastMessage: "Anyone watching the game?"),
        Chatroom(name: "Announcements", memberCount: 52, isActive: false, lastMessage: "New guild event tomorrow!"),
    ]
}
