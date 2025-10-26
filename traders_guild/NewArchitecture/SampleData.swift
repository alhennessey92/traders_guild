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
            isOnline: true
        )
    )
    
    static let sampleGuild = GuildDTO(
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
    )
    
    
    
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
                isOnline: true
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
                isOnline: false
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
            isOnline: true
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
            isOnline: false
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
            isOnline: true
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
            isOnline: true
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
            isOnline: false
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
                isOnline: true
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
                isOnline: false
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
                isOnline: false
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
                    isOnline: true
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
                    isOnline: false
                )
            ],
            isImportant: true,
            canEdit: false
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
                isOnline: true
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
            canEdit: false
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
    
    // MARK: - Watchlists (with embedded GuildMembershipDTO author + SymbolDTO array)
    static let watchlists: [GuildWatchlistDTO] = [
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
                isOnline: true
            ),
            dateCreated: Date(timeIntervalSinceNow: -1987200),
            symbols: [symbols[0], symbols[1], symbols[2]],
            symbolCount: 15,
            lastUpdated: "Updated 5 min ago"
        ),
        GuildWatchlistDTO(
            id: UUID(uuidString: "843e4567-e89b-12d3-a456-426614174051")!,
            guildId: UUID(uuidString: "b23e4567-e89b-12d3-a456-426614174002")!,
            name: "Crypto Portfolio",
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
                isOnline: true
            ),
            dateCreated: Date(timeIntervalSinceNow: -864000),
            symbols: [symbols[4], symbols[5]],
            symbolCount: 5,
            lastUpdated: "Updated 1 hour ago"
        )
    ]
    
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
                isOnline: true
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
                isOnline: true
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
                isOnline: false
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
    static let chatrooms: [GuildChatroomDTO] = [
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
                    isOnline: true
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
                isOnline: true
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
                isOnline: true
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
    static let directMessages: [DMDTO] = [
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
                isOnline: true
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
                    isOnline: true
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
                isOnline: false
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
                    isOnline: false
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
                isOnline: true
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
                        isOnline: true
                    ),
                    isOpen: true
                )
            ],
            mutualGuildCount: 2,
            lastSeen: "Active 15 min ago"
        )
    ]
}
