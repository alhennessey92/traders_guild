//
//  APIService.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//


import Foundation

class MockAPIService {
    
    // Simulate network delay
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    // ================================================================================================
    // MARK: - Authentication
    // ================================================================================================
    
    func signUp(data: SignupData) async throws -> authResponse {
        try await simulateNetworkDelay()
        
        // Mock successful signup
        return authResponse(
            user: SampleData.currentUser,
            token: "mock-jwt-token-\(UUID().uuidString)"
        )
    }
    
    func login(email: String, password: String) async throws -> authResponse {
        try await simulateNetworkDelay()
        
        // ✅ Mock successful login with sample data
        return authResponse(
            user: SampleData.currentUser,
            token: "mock-jwt-token-\(UUID().uuidString)"
        )
    }
    
    // ================================================================================================
    // MARK: - Guild Operations
    // ================================================================================================
    
    /// fetch all open guilds for signup that require no authentication
    func fetchOpenGuilds() async throws -> [GuildDTO] {
        try await simulateNetworkDelay()
        return SampleData.openGuilds
    }
    
    /// Fetch guilds user is joined
    func fetchUserGuilds() async throws -> [GuildDTO] {
        try await simulateNetworkDelay()
        // ✅ Return guilds the user is a member of
        return [SampleData.sampleGuild]  // User is member of this guild
    }
    
    func fetchGuildById(guildId: UUID) async throws -> GuildDTO? {
        try await simulateNetworkDelay()
        
        // Return mock guild with matching ID
//        return SampleData.openGuilds.first { $0.id == guildId }
//            ?? SampleData.sampleGuild
        return SampleData.sampleGuild
    }
    
    func joinGuild(guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful join
    }
    
    func leaveGuild(guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful leave
    }
    
    
    func fetchGuildAnnouncements(guildId: UUID) async throws -> [GuildAnnouncementDTO] {
        try await simulateNetworkDelay()
        return SampleData.announcements
    }

    func fetchGuildEvents(guildId: UUID) async throws -> [GuildEventDTO] {
        try await simulateNetworkDelay()
        return SampleData.events
    }

    func fetchGuildMembers(guildId: UUID) async throws -> [GuildMembershipDTO] {
        try await simulateNetworkDelay()
        return SampleData.guildMemberships
    }

    func fetchGuildWatchlists(guildId: UUID) async throws -> [GuildWatchlistDTO] {
        try await simulateNetworkDelay()
        return SampleData.watchlists
    }
}

// ================================================================================================
// MARK: - Response Models
// ================================================================================================

struct authResponse {
    let user: CurrentUserDTO
    let token: String
}



//import Foundation
//import SwiftUI
//
//// ================================================================================================
//// MARK: - TEMP: Mock API Service
//// ================================================================================================
//// DELETE this when connecting to real backend
//// Simulates network calls with sample data
//// ================================================================================================
//
//class MockAPIService {
//    
//    // Simulate network delay
//    private func simulateNetworkDelay() async throws {
//        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
//    }
//    
//    
//    func fetchGuilds() async -> [GuildDTO] {
//        try? await Task.sleep(nanoseconds: 500_000_000)
//        return SampleData.guilds
//    }
//    
//    func fetchOpenGuilds() async throws -> [GuildDTO] {
//        return SampleData.openGuilds
//    }
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//
////    func fetchAnnouncements() async -> [GuildAnnouncementDTO] {
////        try? await Task.sleep(nanoseconds: 300_000_000)
////        return SampleData.announcements()
////    }
//    
//    func fetchEvents(guildId: UUID) async -> [GuildEventDTO] {
//        return [] // Add sample events as needed
//    }
//    
//    func fetchChatrooms(guildId: UUID) async -> [GuildChatroomDTO] {
//        return [] // Add sample chatrooms as needed
//    }
//    
//    func fetchWatchlists(guildId: UUID) async -> [GuildWatchlistDTO] {
//        return [] // Add sample watchlists as needed
//    }
//    
//}
