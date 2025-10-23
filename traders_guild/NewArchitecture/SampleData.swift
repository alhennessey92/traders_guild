//
//  SampleData.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//
import Foundation
import SwiftUI
// ================================================================================================
// MARK: - SAMPLE DATA
// ================================================================================================
// Static data for development and testing
// DELETE this entire section when connecting to real API
// Used to build and test UI before backend is ready
// ================================================================================================

struct SampleData {
    
    // MARK: Current User
    /// Simulated logged-in user
    static let currentUser = CurrentUserDTO(
        id: UUID(),
        email: "user@example.com",
        name: "John Developer",
        username: "johndev",
        avatarURL: "https://example.com/avatar.jpg",
        globalReputation: 3250,
        isPremium: true,
        notificationCount: 3,
        unreadMessages: 5
    )
    
    // MARK: Sample Members
    static let members = [
        GuildMemberDTO(
            id: UUID(),
            name: "Alex Thompson",
            avatarURL: "https://example.com/avatar1.jpg",
            role: .admin,
            reputation: 2450,
            isOnline: true,
            globalReputation: 5200
        ),
        GuildMemberDTO(
            id: UUID(),
            name: "Sarah Chen",
            avatarURL: "https://example.com/avatar2.jpg",
            role: .moderator,
            reputation: 1850,
            isOnline: true,
            globalReputation: 3900
        ),
        GuildMemberDTO(
            id: UUID(),
            name: "Marcus Johnson",
            avatarURL: nil,
            role: .member,
            reputation: 920,
            isOnline: false,
            globalReputation: 1200
        )
    ]
    
    // MARK: Sample Guilds
    static let guilds = [
        GuildDTO(
            id: UUID(),
            name: "Tech Traders United",
            description: "A community for technology-focused traders sharing insights and strategies",
            reputation: 8500,
            accuracy: 78,
            memberCount: 1247,
            owner: members[0],
            dateCreated: Date().addingTimeInterval(-86400 * 180),
            imageURL: "https://example.com/guild1.jpg",
            isJoined: true,
            currentMemberRole: .member
        ),
        GuildDTO(
            id: UUID(),
            name: "Crypto Futures Hub",
            description: "Advanced cryptocurrency and futures trading discussions",
            reputation: 12300,
            accuracy: 82,
            memberCount: 3421,
            owner: members[1],
            dateCreated: Date().addingTimeInterval(-86400 * 365),
            imageURL: "https://example.com/guild2.jpg",
            isJoined: false,
            currentMemberRole: nil
        )
    ]
    
    // Generate functions return fresh data each time
    static func announcements(for guildId: UUID) -> [GuildAnnouncementDTO] {
        return [
            GuildAnnouncementDTO(
                id: UUID(),
                guildId: guildId,
                author: members[0],
                title: "Weekly Market Analysis",
                content: "Full content here...",
                preview: "This week has shown significant...",
                postedAt: Date().addingTimeInterval(-3600 * 2),
                timeAgoFormatted: "2 hours ago",
                isImportant: true,
                isRead: false,
                readCount: 234
            )
        ]
    }
    
    // Add other sample data generators as needed...
}
