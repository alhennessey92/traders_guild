//
//  Guild.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import Foundation
import SwiftUI






// MARK: - Guild Model
struct Guild: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let reputation: Int
    let accuracy: Int
    let owner: UUID
    let dateCreated: Date
    
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "No description",
        reputation: Int = 0,
        accuracy: Int = 0,
        owner: UUID,
        dateCreated: Date
        
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.reputation = reputation
        self.accuracy = accuracy
        self.owner = owner
        self.dateCreated = dateCreated
        
    }
    // Convenience lookup using sample users (replace with real data source in app layer)
    var authorUser: User? {
        User.sampleUsers.first { $0.id == owner }
    }
    var authorRole: UserRole? { authorUser?.role }
    var authorName: String? { authorUser?.name }
    var authorMembership: GuildMembership? {
        GuildMembership.currentGuildMemberships.first { $0.userId == owner && $0.guildId == id }
    }
}


// MARK: - Sample Memberships
struct GuildMembership: Identifiable, Codable, Equatable {
    let id: UUID
    let guildId: UUID
    let userId: UUID
    let roleInGuild: UserRole
    let dateJoined: Date
    let reputation: Int
    
    init(
        id: UUID = UUID(),
        guildId: UUID,
        userId: UUID,
        roleInGuild: UserRole,
        dateJoined: Date = Date(),
        reputation: Int = 0
    ) {
        self.id = id
        self.guildId = guildId
        self.userId = userId
        self.roleInGuild = roleInGuild
        self.dateJoined = dateJoined
        self.reputation = reputation
    }
    
    // MARK: - Computed Properties
    
    // GET User from userId
    var user: User? {
        User.sampleUsers.first { $0.id == userId }
    }
    
    // GET Guild from guildId
    var guild: Guild? {
        Guild.allGuilds.first { $0.id == guildId }
    }
    
    // Convenience properties
    var userName: String? {
        user?.name
    }
    
    var guildName: String? {
        guild?.name
    }
    
    var userGlobalReputation: Int? {
        user?.globalReputation
    }
    
    var isUserOnline: Bool {
        user?.isOnline ?? false
    }
    
    // Time-based helpers
    var timeInGuild: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: dateJoined, relativeTo: Date())
    }
    
    var daysInGuild: Int {
        Calendar.current.dateComponents([.day], from: dateJoined, to: Date()).day ?? 0
    }
}


// MARK: - User Friends Model
struct GuildFriends: Identifiable, Codable, Equatable {
    var id: UUID
    var userID: UUID
    var friendID: UUID
    var dateFriendAdded: Date
    
    init(
        id: UUID = UUID(),
        userID: UUID,
        friendID: UUID,
        dateFriendAdded: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.friendID = friendID
        self.dateFriendAdded = dateFriendAdded
    }
}



// MARK: - Announcement Models
struct GuildAnnouncement: Identifiable, Codable, Equatable {
    let id: UUID
    let guildId: UUID
    let membershipId: UUID
    let title: String
    let content: String
    let postedAt: Date
    let isImportant: Bool
    let readBy: Set<UUID>
    
    // Custom initializer with defaults
    init(
        id: UUID = UUID(),
        guildId: UUID,
        membershipId: UUID,
        title: String,
        content: String,
        postedAt: Date,
        isImportant: Bool,
        readBy: Set<UUID> = []
    ) {
        self.id = id
        self.guildId = guildId
        self.membershipId = membershipId
        self.title = title
        self.content = content
        self.postedAt = postedAt
        self.isImportant = isImportant
        self.readBy = readBy
    }
    
    // Computed properties for display
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: postedAt, relativeTo: Date())
    }
    
    var preview: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    // GET Guild
    var announcementGuild: Guild? {
        Guild.allGuilds.first { $0.id == guildId }
    }
    
    // GET Membership
    var authorMembership: GuildMembership? {
        GuildMembership.currentGuildMemberships.first { $0.id == membershipId }
    }
    
    // GET User through membership (chain lookup)
    var authorUser: User? {
        guard let membership = authorMembership else { return nil }
        return User.sampleUsers.first { $0.id == membership.userId }
    }
    
    // GET Role from membership (guild-specific role)
    var authorRole: UserRole? {
        authorMembership?.roleInGuild
    }
    
    // GET Name from user
    var authorName: String? {
        authorUser?.name
    }
    
    // GET guild reputation from user
    var authorGuildReputation: Int? {
        authorMembership?.reputation
    }
}


// MARK: - Guild Event Model
struct GuildEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let guildId: UUID
    let authorMembershipId: UUID
    let title: String
    let content: String
    let postedAt: Date
    let eventDate: Date
    let isImportant: Bool
    let noAttending: Int
    let readBy: Set<UUID>
    
    init(
        id: UUID = UUID(),
        guildId: UUID,
        authorMembershipId: UUID,
        title: String,
        content: String,
        postedAt: Date,
        eventDate: Date,
        isImportant: Bool,
        noAttending: Int,
        readBy: Set<UUID> = []
    ) {
        self.id = id
        self.guildId = guildId
        self.authorMembershipId = authorMembershipId
        self.title = title
        self.content = content
        self.postedAt = postedAt
        self.eventDate = eventDate
        self.isImportant = isImportant
        self.noAttending = noAttending
        self.readBy = readBy
    }
    
    // Computed properties for display
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: postedAt, relativeTo: Date())
    }
    
    var preview: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    // GET Guild
    var eventGuild: Guild? {
        Guild.allGuilds.first { $0.id == guildId }
    }
    
    // GET Membership
    var authorMembership: GuildMembership? {
        GuildMembership.currentGuildMemberships.first { $0.id == authorMembershipId }
    }
    
    // GET User through membership (chain lookup)
    var authorUser: User? {
        guard let membership = authorMembership else { return nil }
        return User.sampleUsers.first { $0.id == membership.userId }
    }
    
    // GET Role from membership (guild-specific role)
    var authorRole: UserRole? {
        authorMembership?.roleInGuild
    }
    
    // GET Name from user
    var authorName: String? {
        authorUser?.name
    }
}



// MARK: - Guild Watchlist
struct GuildWatchlist: Identifiable, Codable, Equatable {
    let id: UUID
    let guildId: UUID
    let authorMembershipId: UUID
    let name: String
    let dateCreated: Date
    var symbols: [UUID]

    init(
        id: UUID = UUID(),
        guildId: UUID,
        authorMembershipId: UUID,
        name: String,
        dateCreated: Date = Date(),
        symbols: [UUID] = []
    ) {
        self.id = id
        self.guildId = guildId
        self.authorMembershipId = authorMembershipId
        self.name = name
        self.dateCreated = dateCreated
        self.symbols = symbols
    }
    
    // GET Guild
    var currentGuild: Guild? {
        Guild.allGuilds.first { $0.id == guildId }
    }
    
    // GET Membership
    var authorMembership: GuildMembership? {
        GuildMembership.currentGuildMemberships.first { $0.id == authorMembershipId }
    }
    
    // GET User through membership (chain lookup)
    var authorUser: User? {
        guard let membership = authorMembership else { return nil }
        return User.sampleUsers.first { $0.id == membership.userId }
    }
    
    // GET Role from membership (guild-specific role)
    var authorRole: UserRole? {
        authorMembership?.roleInGuild
    }
    
    // GET Name from user
    var authorName: String? {
        authorUser?.name
    }
    
    // Symbol helpers
    var firstWatchlistSymbol: Symbol? {
        Symbol.sampleSymbol.first { symbols.contains($0.id) }
    }
    
    var symbolObjects: [Symbol] {
        symbols.compactMap { symbolID in
            Symbol.sampleSymbol.first(where: { $0.id == symbolID })
        }
    }
}





// MARK: - SAMPLE DATA




struct GuildIDs{
    static let kaosGuild = UUID()
    static let megaGuild = UUID()
}



// MARK: -  Sample Guild

extension Guild{
    static let allGuilds: [Guild] = [
        Guild(
            id: GuildIDs.kaosGuild,
            name: "KAOS",
            description: "A great description of the kaos guild",
            reputation: 1293,
            accuracy: 34,
            owner: UserIDs.seanPain,
            dateCreated: Date().addingTimeInterval(-3600)
    
        ),
        Guild(
            id: GuildIDs.megaGuild,
            name: "MEGA",
            description: "A great description of the kaos guild",
            reputation: 12312,
            accuracy: 43,
            owner: UserIDs.bullRunner,
            dateCreated: Date().addingTimeInterval(-3600)
 
        )
    ]
    
}


struct MembershipIDs {
    static let currentUserKaos = UUID()
    static let seanPainKaos = UUID()
    static let tradeMasterKaos = UUID()
    static let bullRunnerKaos = UUID()
    static let stockHawkKaos = UUID()
    static let nightOwlKaos = UUID()
    static let chartWizardMega = UUID()
    static let marketGuruMega = UUID()
    static let oldFriendMega = UUID()
    static let quietInvestorMega = UUID()
    static let chartWizardKaos = UUID()
    static let marketGuruKaos = UUID()
}

extension GuildMembership {
    
    // KAOS Guild members
    static let currentGuildMemberships: [GuildMembership] = [
        
        GuildMembership(
            id: MembershipIDs.currentUserKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.currentUser,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*30),
            reputation: 234
        ),
        GuildMembership(
            id: MembershipIDs.seanPainKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.seanPain,
            roleInGuild: .moderator,
            dateJoined: Date().addingTimeInterval(-3600*24*60),
            reputation: 6
        ),
        GuildMembership(
            id: MembershipIDs.tradeMasterKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.tradeMaster,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*15),
            reputation: 345
        ),
        GuildMembership(
            id: MembershipIDs.bullRunnerKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.bullRunner,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*7),
            reputation: 45
        ),
        GuildMembership(
            id: MembershipIDs.stockHawkKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.stockHawk,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*3),
            reputation: 567
        ),
        GuildMembership(
            id: MembershipIDs.nightOwlKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.nightOwl,
            roleInGuild: .admin,
            dateJoined: Date().addingTimeInterval(-3600*24*45),
            reputation: 234
        ),
        GuildMembership(
            id: MembershipIDs.chartWizardKaos,  // ADD THIS
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.chartWizard,
            roleInGuild: .moderator,
            dateJoined: Date().addingTimeInterval(-3600*24*50),
            reputation: 345
        ),
        GuildMembership(
            id: MembershipIDs.marketGuruKaos,  // ADD THIS
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.marketGuru,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*25),
            reputation: 56635
        )
    ]
    
    
    // KAOS Guild members that are online and not friends
    static let onlineNonFriendGuildMembers: [GuildMembership] = [
        
        GuildMembership(
            id: MembershipIDs.seanPainKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.seanPain,
            roleInGuild: .moderator,
            dateJoined: Date().addingTimeInterval(-3600*24*60),
            reputation: 6
        ),
        GuildMembership(
            id: MembershipIDs.bullRunnerKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.bullRunner,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*7),
            reputation: 45
        ),
        GuildMembership(
            id: MembershipIDs.stockHawkKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.stockHawk,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*3),
            reputation: 567
        ),
        GuildMembership(
            id: MembershipIDs.marketGuruKaos,  // ADD THIS
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.marketGuru,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*25),
            reputation: 56635
        )
    ]
    
    
    // KAOS Guild members that are offline and not friends
    static let offlineNonFriendGuildMembers: [GuildMembership] = [
        
        GuildMembership(
            id: MembershipIDs.chartWizardKaos,  // ADD THIS
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.chartWizard,
            roleInGuild: .moderator,
            dateJoined: Date().addingTimeInterval(-3600*24*50),
            reputation: 345
        )
    ]
    
    // KAOS Guild members that are offline and not friends
    static let friendGuildMembers: [GuildMembership] = [
        
        GuildMembership(
            id: MembershipIDs.nightOwlKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.nightOwl,
            roleInGuild: .admin,
            dateJoined: Date().addingTimeInterval(-3600*24*45),
            reputation: 234
        ),
        GuildMembership(
            id: MembershipIDs.tradeMasterKaos,
            guildId: GuildIDs.kaosGuild,
            userId: UserIDs.tradeMaster,
            roleInGuild: .member,
            dateJoined: Date().addingTimeInterval(-3600*24*15),
            reputation: 345
        )
    ]
    
    
}



// MARK: - Guild Friends
extension GuildFriends{
    static let guildFriends: [GuildFriends] = [
        GuildFriends(userID: UserIDs.currentUser, friendID: UserIDs.nightOwl, dateFriendAdded: Date().addingTimeInterval(-7200)),
        GuildFriends(userID: UserIDs.currentUser, friendID: UserIDs.tradeMaster, dateFriendAdded: Date().addingTimeInterval(-7200))
    ]
}




// MARK: - Guild Announcements
// Note: GuildUser sample data removed, reference User.sampleUsers instead
extension GuildAnnouncement {
    static let guildAnnouncements: [GuildAnnouncement] = [
        GuildAnnouncement(
            guildId: GuildIDs.kaosGuild,
            membershipId: MembershipIDs.nightOwlKaos,  // nightOwl is admin in KAOS
            title: "New Trading Tournament Announced",
            content: "We're excited to announce our biggest trading tournament yet! Starting next Monday, all guild members can participate in a week-long competition to see who can achieve the highest returns.\n\nPrizes include:\n• 1st Place: 1000 reputation points + Special badge\n• 2nd Place: 500 reputation points\n• 3rd Place: 250 reputation points\n\nAll trades must be documented with screenshots and verified by moderators. Good luck to everyone participating!",
            postedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            isImportant: true
        ),
        GuildAnnouncement(
            guildId: GuildIDs.kaosGuild,
            membershipId: MembershipIDs.seanPainKaos,  // seanPain is moderator in KAOS
            title: "Market Analysis Session - This Friday",
            content: "Join us this Friday at 7 PM EST for our weekly market analysis session. We'll be reviewing the latest market trends, discussing upcoming earnings reports, and sharing trading strategies.\n\nTopics to cover:\n• SPY technical analysis\n• Earnings plays for next week\n• Crypto market outlook\n• Q&A session\n\nAll guild members are welcome to join and share their insights!",
            postedAt: Date().addingTimeInterval(-7200), // 2 hours ago
            isImportant: false
        ),
        GuildAnnouncement(
            guildId: GuildIDs.kaosGuild,
            membershipId: MembershipIDs.currentUserKaos,  // Current user posting
            title: "New Member Welcome",
            content: "Hey everyone! Just wanted to introduce myself. Looking forward to learning and sharing trading strategies with you all. Let's make some profitable trades together! 📈",
            postedAt: Date().addingTimeInterval(-28800), // 8 hours ago
            isImportant: false
        )
    ]
}

// EVENTS
extension GuildEvent {
    static let guildEvents: [GuildEvent] = [
        GuildEvent(
            guildId: GuildIDs.kaosGuild,
            authorMembershipId: MembershipIDs.nightOwlKaos,
            title: "Trading Tournament - Week 1",
            content: "Join us for our first weekly trading tournament! Compete with guild members to see who can achieve the best risk-adjusted returns. Top 3 performers win reputation points and badges. All trades must be documented in the #trades channel.",
            postedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            eventDate: Date().addingTimeInterval(86400 * 3), // 3 days from now
            isImportant: true,
            noAttending: 34
        ),
        GuildEvent(
            guildId: GuildIDs.kaosGuild,
            authorMembershipId: MembershipIDs.seanPainKaos,
            title: "Market Analysis Session",
            content: "Weekly live market analysis session. We'll cover technical setups, upcoming earnings, and macro events. Bring your questions!",
            postedAt: Date().addingTimeInterval(-7200), // 2 hours ago
            eventDate: Date().addingTimeInterval(86400 * 5), // 5 days from now
            isImportant: false,
            noAttending: 18
        ),
        GuildEvent(
            guildId: GuildIDs.kaosGuild,
            authorMembershipId: MembershipIDs.currentUserKaos,
            title: "Beginner Trading Q&A",
            content: "Open Q&A session for new traders. No question is too basic! Come learn about chart reading, risk management, and position sizing.",
            postedAt: Date().addingTimeInterval(-14400), // 4 hours ago
            eventDate: Date().addingTimeInterval(86400 * 2), // 2 days from now
            isImportant: false,
            noAttending: 12
        )
    ]
}


// EVENTS
extension GuildWatchlist {
    static let guildWatchlist: [GuildWatchlist] = [
        GuildWatchlist(
            guildId: GuildIDs.kaosGuild,
            authorMembershipId: MembershipIDs.nightOwlKaos,
            name: "Main Watchlist",
            dateCreated: Date().addingTimeInterval(-3600),
            symbols: [SymbolIDs.eurusd, SymbolIDs.audusd, SymbolIDs.gold]
        )
    ]
}

