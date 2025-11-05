////
////  SampleData.swift
////  traders_guild
////
////  Created by Al Hennessey on 23/10/2025.
////

import Foundation

struct SampleData {
    
    // MARK: - Current User
    // MARK: - Current User
    static let currentUser = CurrentUserDTO(
        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
        email: "john.developer@email.com",
        name: "John Developer",
        username: "johndev",
        avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
        globalReputation: 2450,
        notificationCount: 3,
        unreadMessages: 7,
        guildMembership: GuildMembershipDTO(
            id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                email: "john.developer@email.com",
                name: "John Developer",
                username: "johndev",
                avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                isOnline: true,
                globalReputation: 2450
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders. We focus on technical analysis, risk management, and collaborative learning. All skill levels welcome!",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .moderator,
            dateJoined: Date(timeIntervalSince1970: 1718712300),
            reputation: 850,
            daysInGuild: 127,
            contributionScore: 78,
            isOnline: true,
            isFriend: false,
            isBlocked: false
        )
    )
    
    static let sampleGuild = GuildMembershipDTO(
        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
        globalMember: GlobalMemberDTO(
            id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
            email: "john.developer@email.com",
            name: "John Developer",
            username: "johndev",
            avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
            isOnline: true,
            globalReputation: 2450
        ),
        guild: GuildDTO(
            id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "KAOS Trading",
            description: "Premier guild for forex and cryptocurrency traders.",
            reputation: 45000,
            accuracy: 78,
            memberCount: 156,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                email: "sarah.masters@email.com",
                name: "Sarah Masters",
                username: "tradingqueen",
                avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                isOnline: true,
                globalReputation: 5820
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1705314600),
            imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
            isJoined: true,
            currentMemberRole: .admin,
            isOpen: true,
            membersOnline: 12
        ),
        roleInGuild: .admin,
        dateJoined: Date(timeIntervalSince1970: 1705314600),
        reputation: 5820,
        daysInGuild: 282,
        contributionScore: 95,
        isOnline: true,
        isFriend: true,
        isBlocked: false
    )
    
    // MARK: - Open Guilds (with embedded GlobalMemberDTO owner)
    static let userGuilds: [GuildDTO] = [
        
        GuildDTO(
            id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "KAOS",
            description: "Premier guild for forex and cryptocurrency traders. We focus on technical analysis, risk management, and collaborative learning. All skill levels welcome!",
            reputation: 45000,
            accuracy: 78,
            memberCount: 156,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                email: "sarah.masters@email.com",
                name: "Sarah Masters",
                username: "tradingqueen",
                avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                isOnline: true,
                globalReputation: 5820
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1705314600),
            imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
            isJoined: true,
            currentMemberRole: .moderator,
            isOpen: true,
            membersOnline: 12
        ),
        GuildDTO(
            id: UUID(uuidString: "b23e4567-e89b-12d3-a456-234234220001")!,
            name: "MEGA",
            description: "Premier guild for forex and cryptocurrency traders. We focus on technical analysis, risk management, and collaborative learning. All skill levels welcome!",
            reputation: 423,
            accuracy: 54,
            memberCount: 12,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "e23e4567-e89b-12d3-a456-426614174005")!,
                email: "crypto.king@email.com",
                name: "Crypto King",
                username: "cryptoking",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 4200
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1705314600),
            imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
            isJoined: true,
            currentMemberRole: .member,
            isOpen: true,
            membersOnline: 1
        )
        
    ]
    
    static let userMembershipGuilds: [GuildMembershipDTO] = [
        GuildMembershipDTO(
            id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                email: "john.developer@email.com",
                name: "John Developer",
                username: "johndev",
                avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                isOnline: true,
                globalReputation: 2450
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .admin,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .admin,
            dateJoined: Date(timeIntervalSince1970: 1705314600),
            reputation: 5820,
            daysInGuild: 282,
            contributionScore: 95,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        GuildMembershipDTO(
            id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                email: "john.developer@email.com",
                name: "John Developer",
                username: "johndev",
                avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                isOnline: true,
                globalReputation: 2450
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "Crypto",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .moderator,
            dateJoined: Date(timeIntervalSince1970: 1710063600),
            reputation: 3200,
            daysInGuild: 228,
            contributionScore: 88,
            isOnline: false,
            isFriend: false,
            isBlocked: false
        )
    ]
    
    
    // MARK: - Open Guilds (with embedded GlobalMemberDTO owner)
    static let openGuilds: [GuildDTO] = [
        
        GuildDTO(
            id: UUID(uuidString: "d23e4567-e89b-12d3-a456-426614174004")!,
            name: "Crypto Warriors",
            description: "Cryptocurrency enthusiasts unite! Day trading, swing trading, and long-term investing strategies.",
            reputation: 38000,
            accuracy: 72,
            memberCount: 203,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "e23e4567-e89b-12d3-a456-426614174005")!,
                email: "crypto.king@email.com",
                name: "Crypto King",
                username: "cryptoking",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 4200
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1710936900),
            imageURL: "https://cdn.tradersguild.com/guilds/crypto-banner.jpg",
            isJoined: false,
            currentMemberRole: nil,
            isOpen: true,
            membersOnline: 12
        ),
        GuildDTO(
            id: UUID(uuidString: "d23e4567-e89b-12d3-a456-426345174004")!,
            name: "KAOS Guild",
            description: "Cryptocurrency enthusiasts unite! Day trading, swing trading, and long-term investing strategies.",
            reputation: 8000,
            accuracy: 72,
            memberCount: 203,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "e23e4567-e89b-12d3-a456-426614174005")!,
                email: "crypto.king@email.com",
                name: "Crypto King",
                username: "cryptoking",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 4200
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1710936900),
            imageURL: "https://cdn.tradersguild.com/guilds/crypto-banner.jpg",
            isJoined: false,
            currentMemberRole: nil,
            isOpen: true,
            membersOnline: 12
        )
        
    ]
    
    // MARK: - Guilds (with embedded GlobalMemberDTO owner)
    static let guilds: [GuildDTO] = [
        GuildDTO(
            id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "KAOS Trading Guild",
            description: "Premier guild for forex and cryptocurrency traders. We focus on technical analysis, risk management, and collaborative learning. All skill levels welcome!",
            reputation: 45000,
            accuracy: 78,
            memberCount: 156,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                email: "sarah.masters@email.com",
                name: "Sarah Masters",
                username: "tradingqueen",
                avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                isOnline: true,
                globalReputation: 5820
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1705314600),
            imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
            isJoined: true,
            currentMemberRole: .moderator,
            isOpen: true,
            membersOnline: 12
        ),
        GuildDTO(
            id: UUID(uuidString: "d23e4567-e89b-12d3-a456-426614174004")!,
            name: "Crypto Warriors",
            description: "Cryptocurrency enthusiasts unite! Day trading, swing trading, and long-term investing strategies.",
            reputation: 38000,
            accuracy: 72,
            memberCount: 203,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "e23e4567-e89b-12d3-a456-426614174005")!,
                email: "crypto.king@email.com",
                name: "Crypto King",
                username: "cryptoking",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 4200
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1710936900),
            imageURL: "https://cdn.tradersguild.com/guilds/crypto-banner.jpg",
            isJoined: false,
            currentMemberRole: nil,
            isOpen: true,
            membersOnline: 12
        ),
        GuildDTO(
            id: UUID(uuidString: "f23e4567-e89b-12d3-a456-426614174006")!,
            name: "Forex Masters",
            description: "Advanced forex trading strategies and live trading sessions daily.",
            reputation: 52000,
            accuracy: 82,
            memberCount: 89,
            owner: GlobalMemberDTO(
                id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                email: "mike.trader@email.com",
                name: "Mike Trader",
                username: "miketrader",
                avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                isOnline: false,
                globalReputation: 3200
            ),
            ownerRole: .admin,
            dateCreated: Date(timeIntervalSince1970: 1698249000),
            imageURL: "https://cdn.tradersguild.com/guilds/forex.jpg",
            isJoined: true,
            currentMemberRole: .member,
            isOpen: false,
            membersOnline: 12
        )
    ]
    
    static let guildStatistics: GuildStatisticsDTO =
        // MARK: - Watchlist 1: Tech Stocks
        GuildStatisticsDTO(
            id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "KAOS Trading",
            totalPredictions: 123,            // Current number of members
            correctPredictions: 43,            // Current number of members
            averageAccuracy: 34,            // Current number of members
            guildRank: 2,            // Current number of members
            newMembers: 1231,            // Current number of members
            activeUsers: 12,            // Current number of members
            predictionsMade: 4124,            // Current number of members
            reputationEarned: 34123
        )
    
    // MARK: - Guild Summaries (with embedded GuildMembershipDTO owner)
    static let guildSummaries: [GuildSummaryDTO] = [
        GuildSummaryDTO(
            id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "KAOS Trading",
            memberCount: 156,
            imageURL: "https://cdn.tradersguild.com/guilds/kaos.jpg",
            reputation: 45000,
            owner: GuildMembershipDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .admin,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .admin,
                dateJoined: Date(timeIntervalSince1970: 1705314600),
                reputation: 5820,
                daysInGuild: 282,
                contributionScore: 95,
                isOnline: true,
                isFriend: true,
                isBlocked: false
            ),
            isOpen: true
        ),
        GuildSummaryDTO(
            id: UUID(uuidString: "d23e4567-e89b-12d3-a456-426614174004")!,
            name: "Crypto Warriors",
            memberCount: 203,
            imageURL: "https://cdn.tradersguild.com/guilds/crypto.jpg",
            reputation: 38000,
            owner: GuildMembershipDTO(
                id: UUID(uuidString: "223e4567-e89b-12d3-a456-426614174009")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "e23e4567-e89b-12d3-a456-426614174005")!,
                    email: "crypto.king@email.com",
                    name: "Crypto King",
                    username: "cryptoking",
                    avatarURL: nil,
                    isOnline: false,
                    globalReputation: 4200
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "d23e4567-e89b-12d3-a456-426614174004")!,
                    name: "Crypto Warriors",
                    description: "Cryptocurrency enthusiasts unite!",
                    reputation: 38000,
                    accuracy: 72,
                    memberCount: 203,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "e23e4567-e89b-12d3-a456-426614174005")!,
                        email: "crypto.king@email.com",
                        name: "Crypto King",
                        username: "cryptoking",
                        avatarURL: nil,
                        isOnline: false,
                        globalReputation: 4200
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1710936900),
                    imageURL: "https://cdn.tradersguild.com/guilds/crypto-banner.jpg",
                    isJoined: false,
                    currentMemberRole: nil,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .admin,
                dateJoined: Date(timeIntervalSince1970: 1710936900),
                reputation: 4200,
                daysInGuild: 217,
                contributionScore: 92,
                isOnline: false,
                isFriend: false,
                isBlocked: false
            ),
            isOpen: true
        )
    ]
    
    // MARK: - Guild Memberships (with embedded GlobalMemberDTO + GuildDTO)
    static let guildMemberships: [GuildMembershipDTO] = [
        GuildMembershipDTO(
            id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                email: "sarah.masters@email.com",
                name: "Sarah Masters",
                username: "tradingqueen",
                avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                isOnline: true,
                globalReputation: 5820
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .admin,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .admin,
            dateJoined: Date(timeIntervalSince1970: 1705314600),
            reputation: 5820,
            daysInGuild: 282,
            contributionScore: 95,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        GuildMembershipDTO(
            id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                email: "mike.trader@email.com",
                name: "Mike Trader",
                username: "miketrader",
                avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                isOnline: false,
                globalReputation: 3200
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .moderator,
            dateJoined: Date(timeIntervalSince1970: 1710063600),
            reputation: 3200,
            daysInGuild: 228,
            contributionScore: 88,
            isOnline: false,
            isFriend: false,
            isBlocked: false
        ),
        GuildMembershipDTO(
            id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                email: "john.developer@email.com",
                name: "John Developer",
                username: "johndev",
                avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                isOnline: true,
                globalReputation: 2450
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .moderator,
            dateJoined: Date(timeIntervalSince1970: 1718712300),
            reputation: 850,
            daysInGuild: 127,
            contributionScore: 78,
            isOnline: true,
            isFriend: false,
            isBlocked: false
        ),
        GuildMembershipDTO(
            id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174011")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174012")!,
                email: "alice.forex@email.com",
                name: "Alice Forex",
                username: "aliceforex",
                avatarURL: "https://cdn.tradersguild.com/avatars/alice.jpg",
                isOnline: true,
                globalReputation: 1500
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .member,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1721131200),
            reputation: 450,
            daysInGuild: 101,
            contributionScore: 65,
            isOnline: true,
            isFriend: true,
            isBlocked: false
        ),
        GuildMembershipDTO(
            id: UUID(uuidString: "623e4567-e89b-12d3-a456-426614174013")!,
            globalMember: GlobalMemberDTO(
                id: UUID(uuidString: "723e4567-e89b-12d3-a456-426614174014")!,
                email: "bob.charts@email.com",
                name: "Bob Charts",
                username: "bobcharts",
                avatarURL: nil,
                isOnline: false,
                globalReputation: 980
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .member,
                isOpen: true,
                membersOnline: 12
            ),
            roleInGuild: .member,
            dateJoined: Date(timeIntervalSince1970: 1724054400),
            reputation: 320,
            daysInGuild: 65,
            contributionScore: 52,
            isOnline: false,
            isFriend: false,
            isBlocked: true
        )
    ]
    
    // MARK: - Announcements (with embedded GuildMembershipDTO author)
    static let announcements: [GuildAnnouncementDTO] = [
        GuildAnnouncementDTO(
            id: UUID(uuidString: "543e4567-e89b-12d3-a456-426614174030")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .admin,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .admin,
                dateJoined: Date(timeIntervalSince1970: 1705314600),
                reputation: 5820,
                daysInGuild: 282,
                contributionScore: 95,
                isOnline: true,
                isFriend: true,
                isBlocked: false
            ),
            title: "New Trading Hours and Market Analysis Session",
            content: """
            Hey everyone! 👋
            
            Starting next week, we're adjusting our live trading sessions to align with the London market open. Sessions will now be at 8:00 AM GMT.
            
            Also, we're introducing weekly market analysis sessions every Friday at 5:00 PM GMT. Come prepared with your charts and questions!
            
            Looking forward to seeing you all there. Let's make some profitable trades together! 📈
            """,
            preview: "Starting next week, we're adjusting our live trading sessions to align with the London market open...",
            postedAt: Date(timeIntervalSinceNow: -7200),
            timeAgoFormatted: "2 hours ago",
            isImportant: true,
            isRead: false,
            readCount: 89
        ),
        GuildAnnouncementDTO(
            id: UUID(uuidString: "543e4567-e89b-12d3-a456-426614174031")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                    email: "mike.trader@email.com",
                    name: "Mike Trader",
                    username: "miketrader",
                    avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                    isOnline: false,
                    globalReputation: 3200
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1710063600),
                reputation: 3200,
                daysInGuild: 228,
                contributionScore: 88,
                isOnline: false,
                isFriend: true,
                isBlocked: false
            ),
            title: "Weekend Trading Workshop",
            content: """
            Join us this Saturday for an intensive workshop on swing trading strategies. We'll cover:
            
            - Entry and exit timing
            - Position sizing
            - Risk management
            - Chart pattern recognition
            
            Bring your questions and let's learn together!
            """,
            preview: "Join us this Saturday for an intensive workshop on swing trading strategies...",
            postedAt: Date(timeIntervalSinceNow: -86400),
            timeAgoFormatted: "1 day ago",
            isImportant: false,
            isRead: true,
            readCount: 124
        )
    ]
    
    // MARK: - Events (with embedded GuildMembershipDTO author + attendees array)
    static let events: [GuildEventDTO] = [
        GuildEventDTO(
            id: UUID(uuidString: "643e4567-e89b-12d3-a456-426614174032")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                    email: "mike.trader@email.com",
                    name: "Mike Trader",
                    username: "miketrader",
                    avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                    isOnline: false,
                    globalReputation: 3200
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1710063600),
                reputation: 3200,
                daysInGuild: 228,
                contributionScore: 88,
                isOnline: false,
                isFriend: true,
                isBlocked: false
            ),
            title: "Live EUR/USD Trading Session",
            content: """
            Join us for a live trading session focusing on EUR/USD. We'll be analyzing the current market conditions, discussing entry and exit strategies, and taking live trades based on our analysis.
            
            **What to bring:**
            - Your charts ready
            - Questions about current positions
            - Trading journal
            
            **Topics covered:**
            - Support/resistance analysis
            - Fibonacci retracements
            - Risk management strategies
            - Position sizing
            
            Perfect for intermediate to advanced traders. Beginners welcome but please review basic concepts first!
            """,
            preview: "Join us for a live trading session focusing on EUR/USD. We'll be analyzing the current market conditions...",
            eventDate: Date(timeIntervalSinceNow: 172800),
            eventDateFormatted: "Saturday, Oct 26 at 2:00 PM GMT",
            timeUntilEvent: "in 2 days",
            postedAt: Date(timeIntervalSinceNow: -345600),
            postedTimeAgo: "4 days ago",
            attendeeCount: 42,
            isAttending: true,
            attendees: [
                GuildMembershipDTO(
                    id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174011")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174012")!,
                        email: "alice.forex@email.com",
                        name: "Alice Forex",
                        username: "aliceforex",
                        avatarURL: "https://cdn.tradersguild.com/avatars/alice.jpg",
                        isOnline: true,
                        globalReputation: 1500
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .member,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1721131200),
                    reputation: 450,
                    daysInGuild: 101,
                    contributionScore: 65,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                GuildMembershipDTO(
                    id: UUID(uuidString: "623e4567-e89b-12d3-a456-426614174013")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "723e4567-e89b-12d3-a456-426614174014")!,
                        email: "bob.charts@email.com",
                        name: "Bob Charts",
                        username: "bobcharts",
                        avatarURL: nil,
                        isOnline: false,
                        globalReputation: 980
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .member,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1724054400),
                    reputation: 320,
                    daysInGuild: 65,
                    contributionScore: 52,
                    isOnline: false,
                    isFriend: false,
                    isBlocked: false
                )
            ],
            isImportant: true,
            canEdit: false,
            isRead: true
        ),
        GuildEventDTO(
            id: UUID(uuidString: "643e4567-e89b-12d3-a456-426614174033")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .admin,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .admin,
                dateJoined: Date(timeIntervalSince1970: 1705314600),
                reputation: 5820,
                daysInGuild: 282,
                contributionScore: 95,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            title: "Monthly Trading Competition",
            content: """
            It's time for our monthly trading competition! 🏆
            
            **Prize Pool:** $500 split between top 3 performers
            **Duration:** November 1-30
            **Rules:** Live account trading only, minimum 10 trades
            
            Register by October 28th to participate!
            """,
            preview: "It's time for our monthly trading competition! Prize pool: $500...",
            eventDate: Date(timeIntervalSinceNow: 604800),
            eventDateFormatted: "Friday, Nov 1 at 12:00 AM GMT",
            timeUntilEvent: "in 7 days",
            postedAt: Date(timeIntervalSinceNow: -86400),
            postedTimeAgo: "1 day ago",
            attendeeCount: 67,
            isAttending: false,
            attendees: [],
            isImportant: true,
            canEdit: false,
            isRead: false
        )
    ]
    
    // MARK: - Symbols
    static let symbols: [SymbolDTO] = [
        SymbolDTO(
            id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174040")!,
            ticker: "AAPL",
            name: "Apple Inc.",
            price: 182.52,
            priceFormatted: "$182.52",
            change: 4.27,
            changeFormatted: "+2.34%",
            changeColor: "green",
            volume: 52345678,
            volumeFormatted: "52.3M",
            marketCap: "2.85T",
            symbolType: .stocks,
            symbolStatus: .closed
        ),
        SymbolDTO(
            id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174042")!,
            ticker: "MSFT",
            name: "Microsoft Corporation",
            price: 378.91,
            priceFormatted: "$378.91",
            change: -2.15,
            changeFormatted: "-0.56%",
            changeColor: "red",
            volume: 28934521,
            volumeFormatted: "28.9M",
            marketCap: "2.81T",
            symbolType: .stocks,
            symbolStatus: .closed
        ),
        SymbolDTO(
            id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174041")!,
            ticker: "GOOGL",
            name: "Alphabet Inc.",
            price: 141.73,
            priceFormatted: "$141.73",
            change: 1.89,
            changeFormatted: "+1.35%",
            changeColor: "green",
            volume: 19876543,
            volumeFormatted: "19.9M",
            marketCap: "1.76T",
            symbolType: .stocks,
            symbolStatus: .closed
        ),
        SymbolDTO(
            id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174043")!,
            ticker: "EUR/USD",
            name: "Euro / US Dollar",
            price: 1.0856,
            priceFormatted: "1.0856",
            change: -0.0023,
            changeFormatted: "-0.21%",
            changeColor: "red",
            volume: 0,
            volumeFormatted: "N/A",
            marketCap: nil,
            symbolType: .forex,
            symbolStatus: .open
        ),
        SymbolDTO(
            id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174044")!,
            ticker: "BTC",
            name: "Bitcoin",
            price: 67234.50,
            priceFormatted: "$67,234.50",
            change: 1832.75,
            changeFormatted: "+2.80%",
            changeColor: "green",
            volume: 28934521000,
            volumeFormatted: "28.9B",
            marketCap: "1.32T",
            symbolType: .cryptocurrency,
            symbolStatus: .open
        ),
        SymbolDTO(
            id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174045")!,
            ticker: "ETH",
            name: "Ethereum",
            price: 3524.18,
            priceFormatted: "$3,524.18",
            change: 87.92,
            changeFormatted: "+2.56%",
            changeColor: "green",
            volume: 15234789000,
            volumeFormatted: "15.2B",
            marketCap: "423.5B",
            symbolType: .cryptocurrency,
            symbolStatus: .open
        ),
        SymbolDTO(
            id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174046")!,
            ticker: "XAUUSD",
            name: "Gold",
            price: 2654.30,
            priceFormatted: "$2,654.30",
            change: -12.45,
            changeFormatted: "-0.47%",
            changeColor: "red",
            volume: 0,
            volumeFormatted: "N/A",
            marketCap: nil,
            symbolType: .commodities,
            symbolStatus: .open
        )
    ]
    
    // MARK: - Sample Symbols (Embedded)
    static let guildWatchlist: GuildWatchlistDTO =
        // MARK: - Watchlist 1: Tech Stocks
        GuildWatchlistDTO(
            id: UUID(uuidString: "843e4567-e89b-12d3-a456-426614174050")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "Tech Stocks Q4 2025",
            author: GuildMembershipDTO(
                id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .admin,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .admin,
                dateJoined: Date(timeIntervalSince1970: 1705314600),
                reputation: 5820,
                daysInGuild: 282,
                contributionScore: 95,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            dateCreated: Date(timeIntervalSinceNow: -1987200),
            symbols: [
                SymbolDTO(
                    id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174040")!,
                    ticker: "AAPL",
                    name: "Apple Inc.",
                    price: 182.52,
                    priceFormatted: "$182.52",
                    change: 4.27,
                    changeFormatted: "+2.34%",
                    changeColor: "green",
                    volume: 52345678,
                    volumeFormatted: "52.3M",
                    marketCap: "2.85T",
                    symbolType: .stocks,
                    symbolStatus: .closed
                ),
                SymbolDTO(
                    id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174042")!,
                    ticker: "MSFT",
                    name: "Microsoft Corporation",
                    price: 378.91,
                    priceFormatted: "$378.91",
                    change: -2.15,
                    changeFormatted: "-0.56%",
                    changeColor: "red",
                    volume: 28934521,
                    volumeFormatted: "28.9M",
                    marketCap: "2.81T",
                    symbolType: .stocks,
                    symbolStatus: .closed
                ),
                SymbolDTO(
                    id: UUID(uuidString: "743e4567-e89b-12d3-a456-426614174041")!,
                    ticker: "GOOGL",
                    name: "Alphabet Inc.",
                    price: 141.73,
                    priceFormatted: "$141.73",
                    change: 1.89,
                    changeFormatted: "+1.35%",
                    changeColor: "green",
                    volume: 19876543,
                    volumeFormatted: "19.9M",
                    marketCap: "1.76T",
                    symbolType: .stocks,
                    symbolStatus: .closed
                )
            ],
            symbolCount: 15,
            lastUpdated: "Updated 5 min ago"
        )
    
    
    
    // MARK: - Get sample notifications for user in guild

    static let userNotifications: [GuildNotificationDTO] = [
        // 1. Personal - New Message (DM)
        GuildNotificationDTO(
            id: UUID(uuidString: "a1111111-1111-1111-1111-111111111111")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "b1111111-1111-1111-1111-111111111111")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c1111111-c111-1111-1111-111111111111")!,
                    email: "sarah.trader@email.com",
                    name: "Sarah Chen",
                    username: "sarahchen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 3200
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .member,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1720000000),
                reputation: 450,
                daysInGuild: 90,
                contributionScore: 72,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .member,
                isOpen: true,
                membersOnline: 12
            ),
            title: "Sarah Chen sent you a message",
            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
            createdDate: Date(timeIntervalSinceNow: -1800),
            notificationType: .personal,
            isRead: false,
            // ✅ NAVIGATION FIELDS - DM Notification
            targetUserId: UUID(uuidString: "b1111111-1111-1111-1111-111111111111")!,
            targetChatroomId: nil,
            targetSymbolId: nil,
            targetSymbolTicker: nil,
            targetAnnouncementId: nil,
            targetMetadata: [
                "message_preview": "Hi Al, sorry i missed...",
                "message_type": "dm"
            ]
        ),
        
        // 2. Symbol - Price Alert
        GuildNotificationDTO(
            id: UUID(uuidString: "a2222222-2222-2222-2222-222222222222")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                    email: "john.developer@email.com",
                    name: "John Developer",
                    username: "johndev",
                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                    isOnline: true,
                    globalReputation: 2450
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1718712300),
                reputation: 850,
                daysInGuild: 127,
                contributionScore: 78,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            title: "BTC/USD reached target price $95,000",
            content: "Your price alert for BTC/USD has been triggered at $95,000",
            createdDate: Date(timeIntervalSinceNow: -3600),
            notificationType: .symbol,
            isRead: false,
            // ✅ NAVIGATION FIELDS - Symbol Notification (FIXED UUID)
            targetUserId: nil,
            targetChatroomId: nil,
            targetSymbolId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,  // ✅ Valid UUID for BTC/USD
            targetSymbolTicker: "BTC/USD",
            targetAnnouncementId: nil,
            targetMetadata: [
                "alert_type": "price_target",
                "price_level": "95000",
                "trigger_direction": "above"
            ]
        ),
        
        // 3. Personal - Member Joined
        GuildNotificationDTO(
            id: UUID(uuidString: "a3333333-3333-3333-3333-333333333333")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "b3333333-3333-3333-3333-333333333333")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c3333333-3333-3333-3333-333333333333")!,
                    email: "mike.scalper@email.com",
                    name: "Mike Johnson",
                    username: "mikescalper",
                    avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                    isOnline: false,
                    globalReputation: 1850
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .member,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSinceNow: -7200),
                reputation: 50,
                daysInGuild: 1,
                contributionScore: 5,
                isOnline: false,
                isFriend: false,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .member,
                isOpen: true,
                membersOnline: 12
            ),
            title: "Mike Johnson joined KAOS Trading Guild",
            content: "Welcome the new member to the guild!",
            createdDate: Date(timeIntervalSinceNow: -7200),
            notificationType: .personal,
            isRead: true,
            // ✅ NAVIGATION FIELDS - User Profile Notification
            targetUserId: UUID(uuidString: "b3333333-3333-3333-3333-333333333333")!,
            targetChatroomId: nil,
            targetSymbolId: nil,
            targetSymbolTicker: nil,
            targetAnnouncementId: nil,
            targetMetadata: [
                "event_type": "member_joined",
                "notification_category": "guild_activity"
            ]
        ),
        
        // 4. Symbol - New Trading Signal
        GuildNotificationDTO(
            id: UUID(uuidString: "a4444444-4444-4444-4444-444444444444")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "b4444444-4444-4444-4444-444444444444")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .admin,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .admin,
                dateJoined: Date(timeIntervalSince1970: 1705314600),
                reputation: 2500,
                daysInGuild: 365,
                contributionScore: 100,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .admin,
                isOpen: true,
                membersOnline: 12
            ),
            title: "New BUY signal posted for EUR/USD",
            content: "Sarah Masters posted a new trading signal for EUR/USD",
            createdDate: Date(timeIntervalSinceNow: -10800),
            notificationType: .symbol,
            isRead: true,
            // ✅ NAVIGATION FIELDS - Symbol Notification (FIXED UUID)
            targetUserId: UUID(uuidString: "b4444444-4444-4444-4444-444444444444")!,
            targetChatroomId: nil,
            targetSymbolId: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,  // ✅ Valid UUID for EUR/USD
            targetSymbolTicker: "EUR/USD",
            targetAnnouncementId: nil,
            targetMetadata: [
                "signal_type": "buy",
                "signal_id": "signal-456",
                "entry_price": "1.0850",
                "confidence": "high"
            ]
        ),
        
        // 5. Personal - Promoted to Moderator
        GuildNotificationDTO(
            id: UUID(uuidString: "a5555555-5555-5555-5555-555555555555")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                    email: "john.developer@email.com",
                    name: "John Developer",
                    username: "johndev",
                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                    isOnline: true,
                    globalReputation: 2450
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1718712300),
                reputation: 850,
                daysInGuild: 127,
                contributionScore: 78,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            title: "You've been promoted to Moderator!",
            content: "Congratulations! You now have moderator privileges in KAOS Trading Guild",
            createdDate: Date(timeIntervalSinceNow: -86400),
            notificationType: .personal,
            isRead: true,
            // ✅ NAVIGATION FIELDS - Announcement Notification (FIXED UUID)
            targetUserId: nil,
            targetChatroomId: nil,
            targetSymbolId: nil,
            targetSymbolTicker: nil,
            targetAnnouncementId: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,  // ✅ Valid UUID
            targetMetadata: [
                "event_type": "role_promotion",
                "old_role": "member",
                "new_role": "moderator",
                "promoted_by": "c23e4567-e89b-12d3-a456-426614174003"
            ]
        ),
        
        // 6. Symbol - High Volatility Alert
        GuildNotificationDTO(
            id: UUID(uuidString: "a6666666-6666-6666-6666-666666666666")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                    email: "john.developer@email.com",
                    name: "John Developer",
                    username: "johndev",
                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                    isOnline: true,
                    globalReputation: 2450
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1718712300),
                reputation: 850,
                daysInGuild: 127,
                contributionScore: 78,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            title: "High volatility detected in GBP/JPY",
            content: "GBP/JPY showing unusual volatility - 2.5% movement in last hour",
            createdDate: Date(timeIntervalSinceNow: -900),
            notificationType: .symbol,
            isRead: true,
            // ✅ NAVIGATION FIELDS - Symbol Notification (FIXED UUID)
            targetUserId: nil,
            targetChatroomId: nil,
            targetSymbolId: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,  // ✅ Valid UUID for GBP/JPY
            targetSymbolTicker: "GBP/JPY",
            targetAnnouncementId: nil,
            targetMetadata: [
                "alert_type": "volatility",
                "volatility_percentage": "2.5",
                "time_period": "1h",
                "current_price": "189.45"
            ]
        ),
        
        // 7. Personal - Guild Announcement
        GuildNotificationDTO(
            id: UUID(uuidString: "a7777777-7777-7777-7777-777777777777")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .admin,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .admin,
                dateJoined: Date(timeIntervalSince1970: 1705314600),
                reputation: 2500,
                daysInGuild: 365,
                contributionScore: 100,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .admin,
                isOpen: true,
                membersOnline: 12
            ),
            title: "Guild Announcement: Weekly Trading Competition",
            content: "Join our weekly trading competition! Top 3 traders win exclusive rewards",
            createdDate: Date(timeIntervalSinceNow: -172800),
            notificationType: .personal,
            isRead: true,
            // ✅ NAVIGATION FIELDS - Announcement Notification (FIXED UUID)
            targetUserId: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
            targetChatroomId: nil,
            targetSymbolId: nil,
            targetSymbolTicker: nil,
            targetAnnouncementId: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,  // ✅ Valid UUID
            targetMetadata: [
                "announcement_type": "competition",
                "competition_id": "comp-789",
                "start_date": "2025-11-01",
                "end_date": "2025-11-07"
            ]
        ),
        
        // 8. Symbol - Breakout Alert
        GuildNotificationDTO(
            id: UUID(uuidString: "a8888888-8888-8888-8888-888888888888")!,
            member: GuildMembershipDTO(
                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                    email: "john.developer@email.com",
                    name: "John Developer",
                    username: "johndev",
                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                    isOnline: true,
                    globalReputation: 2450
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1718712300),
                reputation: 850,
                daysInGuild: 127,
                contributionScore: 78,
                isOnline: true,
                isFriend: true,
                isBlocked: false
            ),
            guild: GuildDTO(
                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                name: "KAOS Trading Guild",
                description: "Premier guild for forex and cryptocurrency traders.",
                reputation: 45000,
                accuracy: 78,
                memberCount: 156,
                owner: GlobalMemberDTO(
                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                    email: "sarah.masters@email.com",
                    name: "Sarah Masters",
                    username: "tradingqueen",
                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                    isOnline: true,
                    globalReputation: 5820
                ),
                ownerRole: .admin,
                dateCreated: Date(timeIntervalSince1970: 1705314600),
                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                isJoined: true,
                currentMemberRole: .moderator,
                isOpen: true,
                membersOnline: 12
            ),
            title: "ETH/USD broke resistance at $3,500",
            content: "ETH/USD has broken through the $3,500 resistance level with strong volume",
            createdDate: Date(timeIntervalSinceNow: -5400),
            notificationType: .symbol,
            isRead: true,
            // ✅ NAVIGATION FIELDS - Symbol Notification (FIXED UUID)
            targetUserId: nil,
            targetChatroomId: nil,
            targetSymbolId: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,  // ✅ Valid UUID for ETH/USD
            targetSymbolTicker: "ETH/USD",
            targetAnnouncementId: nil,
            targetMetadata: [
                "alert_type": "breakout",
                "resistance_level": "3500",
                "breakout_direction": "bullish",
                "volume_indicator": "strong"
            ]
        )
    ]
    

    // ============================================================================
    // UUID FORMAT REFERENCE
    // ============================================================================

    /*
    VALID UUID FORMAT:
    "12345678-1234-1234-1234-123456789012"
     └──8──┘ └4┘ └4┘ └4┘ └────12────┘
     
    PATTERN: 8-4-4-4-12 hexadecimal digits separated by hyphens

    ✅ VALID EXAMPLES:
    - "10000000-0000-0000-0000-000000000001"
    - "a1111111-1111-1111-1111-111111111111"
    - "123e4567-e89b-12d3-a456-426614174000"

    ❌ INVALID EXAMPLES:
    - "symbol-btcusd-001" (not in UUID format)
    - "btc-usd" (too short)
    - "12345" (not enough segments)

    HOW TO GENERATE VALID UUIDS:
    1. Use UUID() to generate random: let id = UUID()
    2. Use UUID(uuidString:) with valid format only
    3. For sample data, use patterns like:
       - Symbols: 10000000-0000-0000-0000-00000000000X
       - Announcements: 20000000-0000-0000-0000-00000000000X
       - Users: Use existing member IDs
    */

    // ============================================================================
    // SYMBOL UUID MAPPING (For Your Backend)
    // ============================================================================

    /*
    When your backend sends notifications, it should use actual symbol UUIDs.
    For sample data, I've used this pattern:

    BTC/USD:  10000000-0000-0000-0000-000000000001
    EUR/USD:  10000000-0000-0000-0000-000000000002
    GBP/JPY:  10000000-0000-0000-0000-000000000003
    ETH/USD:  10000000-0000-0000-0000-000000000004

    Your backend should replace these with real symbol IDs from your database.
    */
    
    
//    static let userNotifications: [GuildNotificationDTO] = [
//        // 1. Personal - New Message
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a1111111-1111-1111-1111-111111111111")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "b1111111-1111-1111-1111-111111111111")!,
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "c1111111-c111-1111-1111-111111111111")!,
//                    email: "sarah.trader@email.com",
//                    name: "Sarah Chen",
//                    username: "sarahchen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 3200
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .member,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .member,
//                dateJoined: Date(timeIntervalSince1970: 1720000000),
//                reputation: 450,
//                daysInGuild: 90,
//                contributionScore: 72,
//                isOnline: true,
//                isFriend: false,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .member,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "Sarah Chen sent you a message",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -1800), // 30 min ago
//            notificationType: .personal,
//            isRead: false
//        ),
//        
//        // 2. Symbol - Price Alert
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a2222222-2222-2222-2222-222222222222")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!, // Current user
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
//                    email: "john.developer@email.com",
//                    name: "John Developer",
//                    username: "johndev",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
//                    isOnline: true,
//                    globalReputation: 2450
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .moderator,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .moderator,
//                dateJoined: Date(timeIntervalSince1970: 1718712300),
//                reputation: 850,
//                daysInGuild: 127,
//                contributionScore: 78,
//                isOnline: true,
//                isFriend: false,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .moderator,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "BTC/USD reached target price $95,000",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -3600), // 1 hour ago
//            notificationType: .symbol,
//            isRead: false
//        ),
//        
//        // 3. Personal - Member Joined
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a3333333-3333-3333-3333-333333333333")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "b3333333-3333-3333-3333-333333333333")!,
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "c3333333-3333-3333-3333-333333333333")!,
//                    email: "mike.scalper@email.com",
//                    name: "Mike Johnson",
//                    username: "mikescalper",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
//                    isOnline: false,
//                    globalReputation: 1850
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .member,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .member,
//                dateJoined: Date(timeIntervalSinceNow: -7200), // 2 hours ago
//                reputation: 50,
//                daysInGuild: 1,
//                contributionScore: 5,
//                isOnline: false,
//                isFriend: false,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .member,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "Mike Johnson joined KAOS Trading Guild",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -7200), // 2 hours ago
//            notificationType: .personal,
//            isRead: true
//        ),
//        
//        // 4. Symbol - New Trading Signal
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a4444444-4444-4444-4444-444444444444")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "b4444444-4444-4444-4444-444444444444")!,
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .admin,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .admin,
//                dateJoined: Date(timeIntervalSince1970: 1705314600),
//                reputation: 2500,
//                daysInGuild: 365,
//                contributionScore: 100,
//                isOnline: true,
//                isFriend: false,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .admin,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "New BUY signal posted for EUR/USD",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -10800), // 3 hours ago
//            notificationType: .symbol,
//            isRead: true
//        ),
//        
//        // 5. Personal - Promoted to Moderator
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a5555555-5555-5555-5555-555555555555")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
//                    email: "john.developer@email.com",
//                    name: "John Developer",
//                    username: "johndev",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
//                    isOnline: true,
//                    globalReputation: 2450
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .moderator,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .moderator,
//                dateJoined: Date(timeIntervalSince1970: 1718712300),
//                reputation: 850,
//                daysInGuild: 127,
//                contributionScore: 78,
//                isOnline: true,
//                isFriend: false,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .moderator,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "You've been promoted to Moderator!",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -86400), // 1 day ago
//            notificationType: .personal,
//            isRead: true
//        ),
//        
//        // 6. Symbol - High Volatility Alert
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a6666666-6666-6666-6666-666666666666")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
//                    email: "john.developer@email.com",
//                    name: "John Developer",
//                    username: "johndev",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
//                    isOnline: true,
//                    globalReputation: 2450
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .moderator,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .moderator,
//                dateJoined: Date(timeIntervalSince1970: 1718712300),
//                reputation: 850,
//                daysInGuild: 127,
//                contributionScore: 78,
//                isOnline: true,
//                isFriend: false,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .moderator,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "High volatility detected in GBP/JPY",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -900), // 15 min ago
//            notificationType: .symbol,
//            isRead: true
//        ),
//        
//        // 7. Personal - Announcement
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a7777777-7777-7777-7777-777777777777")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .admin,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .admin,
//                dateJoined: Date(timeIntervalSince1970: 1705314600),
//                reputation: 2500,
//                daysInGuild: 365,
//                contributionScore: 100,
//                isOnline: true,
//                isFriend: false,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .admin,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "Guild Announcement: Weekly Trading Competition",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -172800), // 2 days ago
//            notificationType: .personal,
//            isRead: true
//        ),
//        
//        // 8. Symbol - Breakout Alert
//        GuildNotificationDTO(
//            id: UUID(uuidString: "a8888888-8888-8888-8888-888888888888")!,
//            member: GuildMembershipDTO(
//                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
//                globalMember: GlobalMemberDTO(
//                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
//                    email: "john.developer@email.com",
//                    name: "John Developer",
//                    username: "johndev",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
//                    isOnline: true,
//                    globalReputation: 2450
//                ),
//                guild: GuildDTO(
//                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                    name: "KAOS Trading Guild",
//                    description: "Premier guild for forex and cryptocurrency traders.",
//                    reputation: 45000,
//                    accuracy: 78,
//                    memberCount: 156,
//                    owner: GlobalMemberDTO(
//                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                        email: "sarah.masters@email.com",
//                        name: "Sarah Masters",
//                        username: "tradingqueen",
//                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                        isOnline: true,
//                        globalReputation: 5820
//                    ),
//                    ownerRole: .admin,
//                    dateCreated: Date(timeIntervalSince1970: 1705314600),
//                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                    isJoined: true,
//                    currentMemberRole: .moderator,
//                    isOpen: true,
//                    membersOnline: 12
//                ),
//                roleInGuild: .moderator,
//                dateJoined: Date(timeIntervalSince1970: 1718712300),
//                reputation: 850,
//                daysInGuild: 127,
//                contributionScore: 78,
//                isOnline: true,
//                isFriend: true,
//                isBlocked: false
//            ),
//            guild: GuildDTO(
//                id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
//                name: "KAOS Trading Guild",
//                description: "Premier guild for forex and cryptocurrency traders.",
//                reputation: 45000,
//                accuracy: 78,
//                memberCount: 156,
//                owner: GlobalMemberDTO(
//                    id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
//                    email: "sarah.masters@email.com",
//                    name: "Sarah Masters",
//                    username: "tradingqueen",
//                    avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
//                    isOnline: true,
//                    globalReputation: 5820
//                ),
//                ownerRole: .admin,
//                dateCreated: Date(timeIntervalSince1970: 1705314600),
//                imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
//                isJoined: true,
//                currentMemberRole: .moderator,
//                isOpen: true,
//                membersOnline: 12
//            ),
//            title: "ETH/USD broke resistance at $3,500",
//            content: "Hi Al, sorry i missed your text, iv looked at the figures in EUR/USD and all looks good",
//            createdDate: Date(timeIntervalSinceNow: -5400), // 90 min ago
//            notificationType: .symbol,
//            isRead: true
//        )
//    ]
    
    
    
    // MARK: - Chatroom Messages (with embedded GuildMembershipDTO author)
    static let chatroomMessages: [ChatroomMessageDTO] = [
        ChatroomMessageDTO(
            id: UUID(uuidString: "a43e4567-e89b-12d3-a456-426614174070")!,
            chatroom: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174060")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174011")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174012")!,
                    email: "alice.forex@email.com",
                    name: "Alice Forex",
                    username: "aliceforex",
                    avatarURL: "https://cdn.tradersguild.com/avatars/alice.jpg",
                    isOnline: true,
                    globalReputation: 1500
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .member,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1721131200),
                reputation: 450,
                daysInGuild: 101,
                contributionScore: 65,
                isOnline: true,
                isFriend: true,
                isBlocked: false
            ),
            content: "Good morning everyone! How are the markets looking today?",
            timestamp: Date(timeIntervalSinceNow: -28800),
            timestampFormatted: "8:15 AM",
            isEdited: false,
            isCurrentUserMessage: false,
            canEdit: false,
            canDelete: false
        ),
        ChatroomMessageDTO(
            id: UUID(uuidString: "a43e4567-e89b-12d3-a456-426614174071")!,
            chatroom: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174060")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                    email: "john.developer@email.com",
                    name: "John Developer",
                    username: "johndev",
                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                    isOnline: true,
                    globalReputation: 2450
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1718712300),
                reputation: 850,
                daysInGuild: 127,
                contributionScore: 78,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            content: "Looking bullish on gold! Expecting a breakout soon.",
            timestamp: Date(timeIntervalSinceNow: -28500),
            timestampFormatted: "8:20 AM",
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true
        ),
        ChatroomMessageDTO(
            id: UUID(uuidString: "a43e4567-e89b-12d3-a456-426614174072")!,
            chatroom: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174060")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                    email: "mike.trader@email.com",
                    name: "Mike Trader",
                    username: "miketrader",
                    avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                    isOnline: false,
                    globalReputation: 3200
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1710063600),
                reputation: 3200,
                daysInGuild: 228,
                contributionScore: 88,
                isOnline: false,
                isFriend: false,
                isBlocked: true
            ),
            content: "Just saw a great setup on EUR/USD! 📈",
            timestamp: Date(timeIntervalSinceNow: -120),
            timestampFormatted: "Just now",
            isEdited: false,
            isCurrentUserMessage: false,
            canEdit: false,
            canDelete: true
        )
    ]
    
    // MARK: - Chatrooms (with embedded ChatroomMessageDTO as lastMessage)
    static let allGuildChatrooms: [GuildChatroomDTO] = [
        GuildChatroomDTO(
            id: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174060")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "general",
            description: "Main chat for guild discussions",
            lastMessage: ChatroomMessageDTO(
                id: UUID(uuidString: "a43e4567-e89b-12d3-a456-426614174073")!,
                chatroom: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174060")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                        email: "mike.trader@email.com",
                        name: "Mike Trader",
                        username: "miketrader",
                        avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                        isOnline: true,
                        globalReputation: 3200
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1710063600),
                    reputation: 3200,
                    daysInGuild: 228,
                    contributionScore: 88,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Just saw a great setup on EUR/USD! 📈",
                timestamp: Date(timeIntervalSinceNow: -120),
                timestampFormatted: "2 min ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false
            ),
            isActive: true,
            lastActivity: Date(timeIntervalSinceNow: -120),
            lastActivityFormatted: "Active 2 min ago",
            unreadCount: 5,
            memberCount: 156,
            isPinned: false,
            isMuted: false,
            canSendMessages: true
        ),
        GuildChatroomDTO(
            id: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174061")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "trading-signals",
            description: "Share your trading signals and setups",
            lastMessage: nil,
            isActive: true,
            lastActivity: Date(timeIntervalSinceNow: -21600),
            lastActivityFormatted: "Active 6 hours ago",
            unreadCount: 0,
            memberCount: 156,
            isPinned: true,
            isMuted: false,
            canSendMessages: true
        )
    ]
    
    // MARK: - Guild Chatroom By ID
    static let chatroomByChatroomId: GuildChatroomDTO =
        GuildChatroomDTO(
            id: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174060")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "general",
            description: "Main chat for guild discussions",
            lastMessage: ChatroomMessageDTO(
                id: UUID(uuidString: "a43e4567-e89b-12d3-a456-426614174073")!,
                chatroom: UUID(uuidString: "943e4567-e89b-12d3-a456-426614174060")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                        email: "mike.trader@email.com",
                        name: "Mike Trader",
                        username: "miketrader",
                        avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                        isOnline: true,
                        globalReputation: 3200
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1710063600),
                    reputation: 3200,
                    daysInGuild: 228,
                    contributionScore: 88,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Just saw a great setup on EUR/USD! 📈",
                timestamp: Date(timeIntervalSinceNow: -120),
                timestampFormatted: "2 min ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false
            ),
            isActive: true,
            lastActivity: Date(timeIntervalSinceNow: -120),
            lastActivityFormatted: "Active 2 min ago",
            unreadCount: 5,
            memberCount: 156,
            isPinned: false,
            isMuted: false,
            canSendMessages: true
        )
    
    // MARK: - DM Messages (with embedded GuildMembershipDTO author)
    static let dmMessages: [DMMessageDTO] = [
        DMMessageDTO(
            id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174090")!,
            dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174080")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174011")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174012")!,
                    email: "alice.forex@email.com",
                    name: "Alice Forex",
                    username: "aliceforex",
                    avatarURL: "https://cdn.tradersguild.com/avatars/alice.jpg",
                    isOnline: true,
                    globalReputation: 1500
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .member,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1721131200),
                reputation: 450,
                daysInGuild: 101,
                contributionScore: 65,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            content: "Hey! Want to discuss that EUR/USD setup?",
            timestamp: Date(timeIntervalSinceNow: -3600),
            timestampFormatted: "1 hour ago",
            isEdited: false,
            isCurrentUserMessage: false,
            canEdit: false,
            canDelete: false,
            isRead: true
        ),
        DMMessageDTO(
            id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174091")!,
            dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174080")!,
            author: GuildMembershipDTO(
                id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                    email: "john.developer@email.com",
                    name: "John Developer",
                    username: "johndev",
                    avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                    isOnline: true,
                    globalReputation: 2450
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1718712300),
                reputation: 850,
                daysInGuild: 127,
                contributionScore: 78,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            content: "Sure! I saw a good entry point this morning.",
            timestamp: Date(timeIntervalSinceNow: -3300),
            timestampFormatted: "55 min ago",
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true,
            isRead: true
        )
    ]
    
    // MARK: - Direct Messages (with embedded GuildMembershipDTO participant + DMMessageDTO)
    static let userDMs: [DMDTO] = [
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174080")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174011")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174012")!,
                    email: "alice.forex@email.com",
                    name: "Alice Forex",
                    username: "aliceforex",
                    avatarURL: "https://cdn.tradersguild.com/avatars/alice.jpg",
                    isOnline: true,
                    globalReputation: 1500
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .member,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1721131200),
                reputation: 450,
                daysInGuild: 101,
                contributionScore: 65,
                isOnline: true,
                isFriend: true,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174092")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174080")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                        email: "john.developer@email.com",
                        name: "John Developer",
                        username: "johndev",
                        avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                        isOnline: true,
                        globalReputation: 2450
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1718712300),
                    reputation: 850,
                    daysInGuild: 127,
                    contributionScore: 78,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Sure! I saw a good entry point this morning.",
                timestamp: Date(timeIntervalSinceNow: -2700),
                timestampFormatted: "45 min ago",
                isEdited: false,
                isCurrentUserMessage: true,
                canEdit: true,
                canDelete: true,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -2700),
            lastActivityFormatted: "45 min ago",
            unreadCount: 3,
            isBlocked: false
        ),
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174081")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                    email: "mike.trader@email.com",
                    name: "Mike Trader",
                    username: "miketrader",
                    avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                    isOnline: false,
                    globalReputation: 3200
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1710063600),
                reputation: 3200,
                daysInGuild: 228,
                contributionScore: 88,
                isOnline: false,
                isFriend: false,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174093")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174081")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174010")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "023e4567-e89b-12d3-a456-426614174007")!,
                        email: "mike.trader@email.com",
                        name: "Mike Trader",
                        username: "miketrader",
                        avatarURL: "https://cdn.tradersguild.com/avatars/mike.jpg",
                        isOnline: false,
                        globalReputation: 3200
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1710063600),
                    reputation: 3200,
                    daysInGuild: 228,
                    contributionScore: 88,
                    isOnline: false,
                    isFriend: true,
                    isBlocked: true
                ),
                content: "See you at the trading session tomorrow!",
                timestamp: Date(timeIntervalSinceNow: -86400),
                timestampFormatted: "Yesterday",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -86400),
            lastActivityFormatted: "Yesterday at 3:15 PM",
            unreadCount: 0,
            isBlocked: false
        )
    ]
    
    // MARK: - Direct Messages (with embedded GuildMembershipDTO participant + DMMessageDTO)
    static let userDMbyUserId: DMDTO =
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174080")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174011")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174012")!,
                    email: "alice.forex@email.com",
                    name: "Alice Forex",
                    username: "aliceforex",
                    avatarURL: "https://cdn.tradersguild.com/avatars/alice.jpg",
                    isOnline: true,
                    globalReputation: 1500
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .member,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1721131200),
                reputation: 450,
                daysInGuild: 101,
                contributionScore: 65,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174092")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174080")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                        email: "john.developer@email.com",
                        name: "John Developer",
                        username: "johndev",
                        avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                        isOnline: true,
                        globalReputation: 2450
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1718712300),
                    reputation: 850,
                    daysInGuild: 127,
                    contributionScore: 78,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Sure! I saw a good entry point this morning.",
                timestamp: Date(timeIntervalSinceNow: -2700),
                timestampFormatted: "45 min ago",
                isEdited: false,
                isCurrentUserMessage: true,
                canEdit: true,
                canDelete: true,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -2700),
            lastActivityFormatted: "45 min ago",
            unreadCount: 3,
            isBlocked: false
        )
    
    
    // MARK: - All Guild Friend DMs
    static let allGuildFriendDM: [DMDTO] = [
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174082")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174012")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174013")!,
                    email: "emma.crypto@email.com",
                    name: "Emma Crypto",
                    username: "emmacrypto",
                    avatarURL: "https://cdn.tradersguild.com/avatars/emma.jpg",
                    isOnline: true,
                    globalReputation: 2800
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1715544000),
                reputation: 980,
                daysInGuild: 168,
                contributionScore: 82,
                isOnline: true,
                isFriend: true,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174094")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174082")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174012")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174013")!,
                        email: "emma.crypto@email.com",
                        name: "Emma Crypto",
                        username: "emmacrypto",
                        avatarURL: "https://cdn.tradersguild.com/avatars/emma.jpg",
                        isOnline: true,
                        globalReputation: 2800
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1715544000),
                    reputation: 980,
                    daysInGuild: 168,
                    contributionScore: 82,
                    isOnline: true,
                    isFriend: true,
                    isBlocked: false
                ),
                content: "Bitcoin looks bullish! Check the 4H chart 📈",
                timestamp: Date(timeIntervalSinceNow: -1800),
                timestampFormatted: "30 min ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false,
                isRead: false
            ),
            lastActivity: Date(timeIntervalSinceNow: -1800),
            lastActivityFormatted: "30 min ago",
            unreadCount: 2,
            isBlocked: false
        ),
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174083")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174013")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174014")!,
                    email: "david.scalper@email.com",
                    name: "David Scalper",
                    username: "davidscalp",
                    avatarURL: "https://cdn.tradersguild.com/avatars/david.jpg",
                    isOnline: false,
                    globalReputation: 4200
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .moderator,
                dateJoined: Date(timeIntervalSince1970: 1706832000),
                reputation: 2100,
                daysInGuild: 270,
                contributionScore: 95,
                isOnline: false,
                isFriend: true,
                isBlocked: true
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174095")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174083")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                        email: "john.developer@email.com",
                        name: "John Developer",
                        username: "johndev",
                        avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                        isOnline: true,
                        globalReputation: 2450
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1718712300),
                    reputation: 850,
                    daysInGuild: 127,
                    contributionScore: 78,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Thanks for the scalping tips yesterday!",
                timestamp: Date(timeIntervalSinceNow: -7200),
                timestampFormatted: "2 hours ago",
                isEdited: false,
                isCurrentUserMessage: true,
                canEdit: true,
                canDelete: true,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -7200),
            lastActivityFormatted: "2 hours ago",
            unreadCount: 0,
            isBlocked: false
        ),
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174084")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174014")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174015")!,
                    email: "lisa.options@email.com",
                    name: "Lisa Options",
                    username: "lisaoptions",
                    avatarURL: "https://cdn.tradersguild.com/avatars/lisa.jpg",
                    isOnline: true,
                    globalReputation: 3600
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1713398400),
                reputation: 1250,
                daysInGuild: 199,
                contributionScore: 87,
                isOnline: true,
                isFriend: true,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174096")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174084")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174014")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174015")!,
                        email: "lisa.options@email.com",
                        name: "Lisa Options",
                        username: "lisaoptions",
                        avatarURL: "https://cdn.tradersguild.com/avatars/lisa.jpg",
                        isOnline: true,
                        globalReputation: 3600
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1713398400),
                    reputation: 1250,
                    daysInGuild: 199,
                    contributionScore: 87,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Want to join the options webinar this weekend?",
                timestamp: Date(timeIntervalSinceNow: -10800),
                timestampFormatted: "3 hours ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -10800),
            lastActivityFormatted: "3 hours ago",
            unreadCount: 1,
            isBlocked: false
        )
    ]

    // MARK: - All Guild Online Non-Friend DMs
    static let allGuildOnlineNonFriendDM: [DMDTO] = [
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174085")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174015")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174016")!,
                    email: "robert.swing@email.com",
                    name: "Robert Swing",
                    username: "robertswing",
                    avatarURL: "https://cdn.tradersguild.com/avatars/robert.jpg",
                    isOnline: true,
                    globalReputation: 1850
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1722772800),
                reputation: 320,
                daysInGuild: 84,
                contributionScore: 52,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174097")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174085")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174015")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174016")!,
                        email: "robert.swing@email.com",
                        name: "Robert Swing",
                        username: "robertswing",
                        avatarURL: "https://cdn.tradersguild.com/avatars/robert.jpg",
                        isOnline: true,
                        globalReputation: 1850
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1722772800),
                    reputation: 320,
                    daysInGuild: 84,
                    contributionScore: 52,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Do you have any thoughts on GBP/JPY right now?",
                timestamp: Date(timeIntervalSinceNow: -900),
                timestampFormatted: "15 min ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false,
                isRead: false
            ),
            lastActivity: Date(timeIntervalSinceNow: -900),
            lastActivityFormatted: "15 min ago",
            unreadCount: 1,
            isBlocked: false
        ),
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174086")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174016")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174017")!,
                    email: "jennifer.day@email.com",
                    name: "Jennifer Day",
                    username: "jennyday",
                    avatarURL: "https://cdn.tradersguild.com/avatars/jennifer.jpg",
                    isOnline: true,
                    globalReputation: 920
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1724803200),
                reputation: 180,
                daysInGuild: 61,
                contributionScore: 38,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174098")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174086")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                        email: "john.developer@email.com",
                        name: "John Developer",
                        username: "johndev",
                        avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                        isOnline: true,
                        globalReputation: 2450
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1718712300),
                    reputation: 850,
                    daysInGuild: 127,
                    contributionScore: 78,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Happy to help! Check the pinned messages in #analysis",
                timestamp: Date(timeIntervalSinceNow: -5400),
                timestampFormatted: "1.5 hours ago",
                isEdited: false,
                isCurrentUserMessage: true,
                canEdit: true,
                canDelete: true,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -5400),
            lastActivityFormatted: "1.5 hours ago",
            unreadCount: 0,
            isBlocked: false
        ),
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174087")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174017")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174018")!,
                    email: "carlos.futures@email.com",
                    name: "Carlos Futures",
                    username: "carlosfutures",
                    avatarURL: "https://cdn.tradersguild.com/avatars/carlos.jpg",
                    isOnline: true,
                    globalReputation: 2650
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1717027200),
                reputation: 740,
                daysInGuild: 136,
                contributionScore: 71,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174099")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174087")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174017")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174018")!,
                        email: "carlos.futures@email.com",
                        name: "Carlos Futures",
                        username: "carlosfutures",
                        avatarURL: "https://cdn.tradersguild.com/avatars/carlos.jpg",
                        isOnline: true,
                        globalReputation: 2650
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1717027200),
                    reputation: 740,
                    daysInGuild: 136,
                    contributionScore: 71,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Crude oil futures looking interesting. Are you tracking WTI?",
                timestamp: Date(timeIntervalSinceNow: -14400),
                timestampFormatted: "4 hours ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -14400),
            lastActivityFormatted: "4 hours ago",
            unreadCount: 0,
            isBlocked: false
        )
    ]

    // MARK: - All Guild Offline Non-Friend DMs
    static let allGuildOfflineNonFriendDM: [DMDTO] = [
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174088")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174018")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174019")!,
                    email: "karen.technical@email.com",
                    name: "Karen Technical",
                    username: "karentech",
                    avatarURL: "https://cdn.tradersguild.com/avatars/karen.jpg",
                    isOnline: false,
                    globalReputation: 1420
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1720569600),
                reputation: 395,
                daysInGuild: 102,
                contributionScore: 58,
                isOnline: false,
                isFriend: false,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174100")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174088")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "a23e4567-e89b-12d3-a456-426614174001")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
                        email: "john.developer@email.com",
                        name: "John Developer",
                        username: "johndev",
                        avatarURL: "https://cdn.tradersguild.com/avatars/johndev.jpg",
                        isOnline: true,
                        globalReputation: 2450
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .moderator,
                    dateJoined: Date(timeIntervalSince1970: 1718712300),
                    reputation: 850,
                    daysInGuild: 127,
                    contributionScore: 78,
                    isOnline: true,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "I'll review your chart analysis when you're back online",
                timestamp: Date(timeIntervalSinceNow: -21600),
                timestampFormatted: "6 hours ago",
                isEdited: false,
                isCurrentUserMessage: true,
                canEdit: true,
                canDelete: true,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -21600),
            lastActivityFormatted: "Today at 9:15 AM",
            unreadCount: 0,
            isBlocked: false
        ),
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174089")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174019")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174020")!,
                    email: "tom.penny@email.com",
                    name: "Tom Penny",
                    username: "tompenny",
                    avatarURL: "https://cdn.tradersguild.com/avatars/tom.jpg",
                    isOnline: false,
                    globalReputation: 680
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1726358400),
                reputation: 125,
                daysInGuild: 43,
                contributionScore: 31,
                isOnline: false,
                isFriend: false,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174101")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174089")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174019")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174020")!,
                        email: "tom.penny@email.com",
                        name: "Tom Penny",
                        username: "tompenny",
                        avatarURL: "https://cdn.tradersguild.com/avatars/tom.jpg",
                        isOnline: false,
                        globalReputation: 680
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1726358400),
                    reputation: 125,
                    daysInGuild: 43,
                    contributionScore: 31,
                    isOnline: false,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Could you recommend some penny stock resources?",
                timestamp: Date(timeIntervalSinceNow: -43200),
                timestampFormatted: "12 hours ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -43200),
            lastActivityFormatted: "Today at 3:15 AM",
            unreadCount: 0,
            isBlocked: false
        ),
        DMDTO(
            id: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174090")!,
            guildId: 1,
            participant: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174020")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174021")!,
                    email: "rachel.momentum@email.com",
                    name: "Rachel Momentum",
                    username: "rachelmomentum",
                    avatarURL: "https://cdn.tradersguild.com/avatars/rachel.jpg",
                    isOnline: false,
                    globalReputation: 2100
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .moderator,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1714521600),
                reputation: 610,
                daysInGuild: 167,
                contributionScore: 69,
                isOnline: false,
                isFriend: true,
                isBlocked: false
            ),
            lastMessage: DMMessageDTO(
                id: UUID(uuidString: "c43e4567-e89b-12d3-a456-426614174102")!,
                dmId: UUID(uuidString: "b43e4567-e89b-12d3-a456-426614174090")!,
                author: GuildMembershipDTO(
                    id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174020")!,
                    globalMember: GlobalMemberDTO(
                        id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174021")!,
                        email: "rachel.momentum@email.com",
                        name: "Rachel Momentum",
                        username: "rachelmomentum",
                        avatarURL: "https://cdn.tradersguild.com/avatars/rachel.jpg",
                        isOnline: false,
                        globalReputation: 2100
                    ),
                    guild: GuildDTO(
                        id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                        name: "KAOS Trading Guild",
                        description: "Premier guild for forex and cryptocurrency traders.",
                        reputation: 45000,
                        accuracy: 78,
                        memberCount: 156,
                        owner: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        ownerRole: .admin,
                        dateCreated: Date(timeIntervalSince1970: 1705314600),
                        imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                        isJoined: true,
                        currentMemberRole: .moderator,
                        isOpen: true,
                        membersOnline: 12
                    ),
                    roleInGuild: .member,
                    dateJoined: Date(timeIntervalSince1970: 1714521600),
                    reputation: 610,
                    daysInGuild: 167,
                    contributionScore: 69,
                    isOnline: false,
                    isFriend: false,
                    isBlocked: false
                ),
                content: "Thanks for the momentum indicator tips!",
                timestamp: Date(timeIntervalSinceNow: -172800),
                timestampFormatted: "2 days ago",
                isEdited: false,
                isCurrentUserMessage: false,
                canEdit: false,
                canDelete: false,
                isRead: true
            ),
            lastActivity: Date(timeIntervalSinceNow: -172800),
            lastActivityFormatted: "Monday at 2:30 PM",
            unreadCount: 0,
            isBlocked: false
        )
    ]
    
    // MARK: - Friends (with embedded GuildMembershipDTO + GuildSummaryDTO array)
    static let friends: [GuildFriendDTO] = [
        GuildFriendDTO(
            id: UUID(uuidString: "d43e4567-e89b-12d3-a456-426614174100")!,
            guild: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            friend: GuildMembershipDTO(
                id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174011")!,
                globalMember: GlobalMemberDTO(
                    id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174012")!,
                    email: "alice.forex@email.com",
                    name: "Alice Forex",
                    username: "aliceforex",
                    avatarURL: "https://cdn.tradersguild.com/avatars/alice.jpg",
                    isOnline: true,
                    globalReputation: 1500
                ),
                guild: GuildDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading Guild",
                    description: "Premier guild for forex and cryptocurrency traders.",
                    reputation: 45000,
                    accuracy: 78,
                    memberCount: 156,
                    owner: GlobalMemberDTO(
                        id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                        email: "sarah.masters@email.com",
                        name: "Sarah Masters",
                        username: "tradingqueen",
                        avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                        isOnline: true,
                        globalReputation: 5820
                    ),
                    ownerRole: .admin,
                    dateCreated: Date(timeIntervalSince1970: 1705314600),
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                    isJoined: true,
                    currentMemberRole: .member,
                    isOpen: true,
                    membersOnline: 12
                ),
                roleInGuild: .member,
                dateJoined: Date(timeIntervalSince1970: 1721131200),
                reputation: 450,
                daysInGuild: 101,
                contributionScore: 65,
                isOnline: true,
                isFriend: false,
                isBlocked: false
            ),
            friendshipDate: Date(timeIntervalSince1970: 1717246800),
            friendshipDuration: "Friends for 5 months",
            mutualGuilds: [
                GuildSummaryDTO(
                    id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                    name: "KAOS Trading",
                    memberCount: 156,
                    imageURL: "https://cdn.tradersguild.com/guilds/kaos.jpg",
                    reputation: 45000,
                    owner: GuildMembershipDTO(
                        id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174008")!,
                        globalMember: GlobalMemberDTO(
                            id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                            email: "sarah.masters@email.com",
                            name: "Sarah Masters",
                            username: "tradingqueen",
                            avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                            isOnline: true,
                            globalReputation: 5820
                        ),
                        guild: GuildDTO(
                            id: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
                            name: "KAOS Trading",
                            description: "Premier guild for forex and cryptocurrency traders.",
                            reputation: 45000,
                            accuracy: 78,
                            memberCount: 156,
                            owner: GlobalMemberDTO(
                                id: UUID(uuidString: "c23e4567-e89b-12d3-a456-426614174003")!,
                                email: "sarah.masters@email.com",
                                name: "Sarah Masters",
                                username: "tradingqueen",
                                avatarURL: "https://cdn.tradersguild.com/avatars/sarah.jpg",
                                isOnline: true,
                                globalReputation: 5820
                            ),
                            ownerRole: .admin,
                            dateCreated: Date(timeIntervalSince1970: 1705314600),
                            imageURL: "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
                            isJoined: true,
                            currentMemberRole: .admin,
                            isOpen: true,
                            membersOnline: 12
                        ),
                        roleInGuild: .admin,
                        dateJoined: Date(timeIntervalSince1970: 1705314600),
                        reputation: 5820,
                        daysInGuild: 282,
                        contributionScore: 95,
                        isOnline: true,
                        isFriend: false,
                        isBlocked: false
                    ),
                    isOpen: true
                )
            ],
            mutualGuildCount: 2,
            lastSeen: "Active 15 min ago"
        )
    ]
}
