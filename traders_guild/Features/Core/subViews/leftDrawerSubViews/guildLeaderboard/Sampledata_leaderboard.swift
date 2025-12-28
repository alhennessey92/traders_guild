//
//  Sampledata_leaderboard.swift
//  traders_guild
//
//  Created by Al Hennessey on 28/12/2025.
//

//
//  SampleData+Leaderboard.swift
//  traders_guild
//
//  Sample data extensions for Leaderboard and Friends lists
//

import Foundation

// MARK: - ================================================================================================
// MARK: - SAMPLE DATA EXTENSIONS FOR LEADERBOARD
// MARK: - ================================================================================================

extension SampleData {
    
    // MARK: - Sample Friends List
    /// Friends are guild members who the current user has added as friends
    static let sampleFriends: [GuildMembershipDTO] = [
        // Friend 1 - High rep trader
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "mike.trader@email.com",
                name: "Mike Trader",
                username: "miketrader",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 3200
            ),
            guild: sampleGuild.guild,
            roleInGuild: .moderator,
            dateJoined: Date(timeIntervalSince1970: 1705314600),
            reputation: 1850,
            daysInGuild: 245,
            contributionScore: 92,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        
        // Friend 2 - Active crypto trader
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "cryptoqueen@email.com",
                name: "Lisa Chen",
                username: "cryptoqueen",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 2800
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1712345600),
            reputation: 1420,
            daysInGuild: 180,
            contributionScore: 76,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        
        // Friend 3 - Forex specialist
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "forex.master@email.com",
                name: "James Wilson",
                username: "forexmaster",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 2100
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1720000000),
            reputation: 980,
            daysInGuild: 120,
            contributionScore: 54,
            isOnline: false,
            isFriend: true,
            isBlocked: false
        ),
        
        // Friend 4 - New but active
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "emma.trades@email.com",
                name: "Emma Rodriguez",
                username: "emmatrades",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 1500
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1725000000),
            reputation: 650,
            daysInGuild: 60,
            contributionScore: 45,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        
        // Friend 5 - Veteran trader
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "old.timer@email.com",
                name: "Robert Smith",
                username: "oldtimer",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 4500
            ),
            guild: sampleGuild.guild,
            roleInGuild: .admin,
            dateJoined: Date(timeIntervalSince1970: 1695000000),
            reputation: 2200,
            daysInGuild: 400,
            contributionScore: 98,
            isOnline: false,
            isFriend: true,
            isBlocked: false
        )
    ]
    
    // MARK: - Global Leaderboard
    /// Top traders across all guilds
    static let sampleGlobalLeaderboard: [GuildMembershipDTO] = [
        // #1 Global - Top trader
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "legendary@email.com",
                name: "Alex Legend",
                username: "legendarytrader",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 12500
            ),
            guild: GuildDTO(
                id: UUID(),
                name: "Elite Traders",
                description: "Top 1% of traders worldwide",
                reputation: 150000,
                accuracy: 92,
                memberCount: 50,
                owner: GlobalMemberDTO(
                    id: UUID(),
                    email: "owner@elite.com",
                    name: "Elite Owner",
                    username: "eliteowner",
                    avatarURL: nil,
                    isOnline: true,
                    globalReputation: 15000
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1600000000),
                imageURL: nil,
                isJoined: false,
                currentMemberRole: nil,
                isOpen: false,
                membersOnline: 25
            ),
            roleInGuild: .admin,
            dateJoined: Date(timeIntervalSince1970: 1600000000),
            reputation: 8500,
            daysInGuild: 800,
            contributionScore: 100,
            isOnline: true,
            isFriend: false,
            isBlocked: false
        ),
        
        // #2 Global
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "protrader@email.com",
                name: "Sarah Pro",
                username: "proptrader",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 10200
            ),
            guild: GuildDTO(
                id: UUID(),
                name: "Pro Trading Academy",
                description: "Professional trading education",
                reputation: 98000,
                accuracy: 88,
                memberCount: 120,
                owner: GlobalMemberDTO(
                    id: UUID(),
                    email: "academy@pro.com",
                    name: "Academy Owner",
                    username: "academyowner",
                    avatarURL: nil,
                    isOnline: false,
                    globalReputation: 11000
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1620000000),
                imageURL: nil,
                isJoined: false,
                currentMemberRole: nil,
                isOpen: true,
                membersOnline: 45
            ),
            roleInGuild: .moderator,
            dateJoined: Date(timeIntervalSince1970: 1620000000),
            reputation: 6800,
            daysInGuild: 600,
            contributionScore: 95,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        
        // #3 Global
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "master@trading.com",
                name: "David Chen",
                username: "masterchen",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 9100
            ),
            guild: GuildDTO(
                id: UUID(),
                name: "Asian Markets Guild",
                description: "Focus on Asian market trading",
                reputation: 75000,
                accuracy: 85,
                memberCount: 200,
                owner: GlobalMemberDTO(
                    id: UUID(),
                    email: "asia@markets.com",
                    name: "Asia Owner",
                    username: "asiaowner",
                    avatarURL: nil,
                    isOnline: true,
                    globalReputation: 8000
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1640000000),
                imageURL: nil,
                isJoined: false,
                currentMemberRole: nil,
                isOpen: true,
                membersOnline: 80
            ),
            roleInGuild: .admin,
            dateJoined: Date(timeIntervalSince1970: 1640000000),
            reputation: 5500,
            daysInGuild: 500,
            contributionScore: 90,
            isOnline: false,
            isFriend: false,
            isBlocked: false
        ),
        
        // More global traders...
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "whale@crypto.com",
                name: "Crypto Whale",
                username: "cryptowhale",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 8500
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1660000000),
            reputation: 4200,
            daysInGuild: 400,
            contributionScore: 85,
            isOnline: true,
            isFriend: false,
            isBlocked: false
        ),
        
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "forex.king@email.com",
                name: "ForexKing",
                username: "forexking",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 7800
            ),
            guild: sampleGuild.guild,
            roleInGuild: .moderator,
            dateJoined: Date(timeIntervalSince1970: 1670000000),
            reputation: 3900,
            daysInGuild: 350,
            contributionScore: 82,
            isOnline: false,
            isFriend: false,
            isBlocked: false
        ),
        
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "swing@trader.com",
                name: "Swing Trader",
                username: "swingtrader",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 7200
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1680000000),
            reputation: 3600,
            daysInGuild: 300,
            contributionScore: 78,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "day@trader.com",
                name: "Day Trader Pro",
                username: "daytraderpro",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 6500
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1690000000),
            reputation: 3200,
            daysInGuild: 250,
            contributionScore: 75,
            isOnline: true,
            isFriend: false,
            isBlocked: false
        ),
        
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "options@queen.com",
                name: "Options Queen",
                username: "optionsqueen",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 5900
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1700000000),
            reputation: 2900,
            daysInGuild: 200,
            contributionScore: 70,
            isOnline: false,
            isFriend: false,
            isBlocked: false
        ),
        
        GuildMembershipDTO(
            id: UUID(),
            globalMember: GlobalMemberDTO(
                id: UUID(),
                email: "scalper@pro.com",
                name: "Scalper Pro",
                username: "scalperpro",
                avatarURL: nil,
                isOnline: true,
                globalReputation: 5200
            ),
            guild: sampleGuild.guild,
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1710000000),
            reputation: 2600,
            daysInGuild: 150,
            contributionScore: 65,
            isOnline: true,
            isFriend: false,
            isBlocked: false
        )
    ]
}
