//
//  GuildUser.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//
import Foundation


// MARK: - Chatroom Model
struct Chatroom: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let memberCount: Int
    let isActive: Bool
    let lastMessage: String?
}
