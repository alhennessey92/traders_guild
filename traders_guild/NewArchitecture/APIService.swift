//
//  APIService.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//

import Foundation
import SwiftUI

// ================================================================================================
// MARK: - TEMP: Mock API Service
// ================================================================================================
// DELETE this when connecting to real backend
// Simulates network calls with sample data
// ================================================================================================

class MockAPIService {
    func fetchGuilds() async -> [GuildDTO] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return SampleData.guilds
    }
    
    func fetchAnnouncements(guildId: UUID) async -> [GuildAnnouncementDTO] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return SampleData.announcements(for: guildId)
    }
    
    func fetchEvents(guildId: UUID) async -> [GuildEventDTO] {
        return [] // Add sample events as needed
    }
    
    func fetchChatrooms(guildId: UUID) async -> [GuildChatroomDTO] {
        return [] // Add sample chatrooms as needed
    }
    
    func fetchWatchlists(guildId: UUID) async -> [GuildWatchlistDTO] {
        return [] // Add sample watchlists as needed
    }
    
}
