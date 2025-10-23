////
////  total_models.swift
////  traders_guild
////
////  Created by Al Hennessey on 22/10/2025.
////
//
////
////  Symbols.swift
////  traders_guild
////
////  Created by Al Hennessey on 09/10/2025.
////
//
//import Foundation
//
//// MARK: - Symbol Type
//enum SymbolType: String, Codable {
//    case forex = "Forex"
//    case commodities = "Commodities"
//    case stocks = "Stocks"
//    case cryptocurrency = "Cryptocurrency"
//}
//
//// MARK: - Symbol Status
//enum SymbolStatus: String, Codable {
//    case open = "Open"
//    case closed = "Closed"
//}
//
//// MARK: - Change Direction
//enum ChangeDirection: String, Codable {
//    case up = "+"
//    case down = "-"
//}
//
//
//
//
//struct Symbol: Identifiable, Codable, Equatable {
//    let id: UUID
//    let ticker: String
//    let symbol: String           // e.g. "AAPL"
//    let fullName: String?     // optional, e.g. "Apple Inc."
//    let addedDate: Date
//    let notes: String?
//    let symbolType: SymbolType
//    let symbolStatus: SymbolStatus
//    let currentPrice: Double
//    let currentChange: Double
//    let changeDirection: ChangeDirection
//    
//    init(
//        id: UUID = UUID(),
//        ticker: String,
//        symbol: String,
//        fullName: String? = nil,
//        addedDate: Date = Date(),
//        notes: String? = nil,
//        symbolType: SymbolType,
//        symbolStatus: SymbolStatus,
//        currentPrice: Double,
//        currentChange: Double = 0.0,
//        changeDirection: ChangeDirection
//        
//    ) {
//        self.id = id
//        self.ticker = ticker
//        self.symbol = symbol
//        self.fullName = fullName
//        self.addedDate = addedDate
//        self.notes = notes
//        self.symbolType = symbolType
//        self.symbolStatus = symbolStatus
//        self.currentPrice = currentPrice
//        self.currentChange = currentChange
//        self.changeDirection = changeDirection
//    }
//}
//
//// SAMPLE DATA
//
//struct SymbolIDs {
//    static let eurusd = UUID()
//    static let audusd = UUID()
//    static let gold = UUID()
//
//}
//
//// Symbols
//extension Symbol {
//    static let sampleSymbol: [Symbol] = [
//        Symbol(
//            id: SymbolIDs.eurusd,
//            ticker: "EURUSD",
//            symbol: "EUR/USD",
//            fullName: "Euro / US Dollar",
//            addedDate: Date().addingTimeInterval(-3600),
//            notes: "Forex", // 1 hour ago
//            symbolType: .forex,
//            symbolStatus: .open,
//            currentPrice: 1.242342,
//            currentChange: 45.342,
//            changeDirection: .down
//            
//        ),
//        
//        Symbol(
//            id: SymbolIDs.audusd,
//            ticker: "AUDUSD",
//            symbol: "AUD/USD",
//            fullName: "Australian Dollar / US Dollar",
//            addedDate: Date().addingTimeInterval(-3600),
//            notes: "Forex",// 1 hour ago
//            symbolType: .forex,
//            symbolStatus: .closed,
//            currentPrice: 2.342113,
//            currentChange: 86.2342,
//            changeDirection: .up
//            
//        
//        ),
//        Symbol(
//            id: SymbolIDs.gold,
//            ticker: "GOLD",
//            symbol: "Gold",
//            fullName: "Gold",
//            addedDate: Date().addingTimeInterval(-3600),
//            notes: "Commodities", // 1 hour ago
//            symbolType: .commodities,
//            symbolStatus: .open,
//            currentPrice: 23.2342,
//            currentChange: 34.4332,
//            changeDirection: .up
//            
//        )
//    ]
//}
//
//
//
//// MARK: - Chatroom Model
//struct Chatroom: Identifiable, Codable, Equatable {
//    let id: UUID
//    let name: String
//    let guildId: UUID
//    let memberCount: Int
//    let isActive: Bool
//    let lastMessage: String?
//    
//    init(
//        id: UUID = UUID(),
//        name: String,
//        guildId: UUID,
//        memberCount: Int,
//        isActive: Bool,
//        lastMessage: String?
//    ) {
//        self.id = id
//        self.name = name
//        self.guildId = guildId
//        self.memberCount = memberCount
//        self.isActive = isActive
//        self.lastMessage = lastMessage
//    }
//    var currentGuild: Guild? {
//        Guild.allGuilds.first { $0.id == guildId }
//    }
//}
//
//// MARK: - Chatroom Message Model
//struct ChatroomMessage: Identifiable, Codable, Equatable {
//    let id: UUID
//    let roomId: UUID
//    let senderMembershipId: UUID // Handled as GuildMembership
//    let content: String
//    let createdAt: Date
//    
//    init(
//        id: UUID = UUID(),
//        roomId: UUID,
//        senderMembershipId: UUID,
//        content: String,
//        createdAt: Date
//    ){
//        self.id = id
//        self.roomId = roomId
//        self.senderMembershipId = senderMembershipId
//        self.content = content
//        self.createdAt = createdAt
//    }
//    // Computed properties for display
//    var timeAgo: String {
//        let formatter = RelativeDateTimeFormatter()
//        formatter.unitsStyle = .abbreviated
//        return formatter.localizedString(for: createdAt, relativeTo: Date())
//    }
//    var currentChatRoom: Chatroom? {
//        Chatroom.sampleChatrooms.first { $0.id == roomId }
//    }
//    
//    
//    // GET Membership
//    var authorMembership: GuildMembership? {
//        GuildMembership.currentGuildMemberships.first { $0.id == senderMembershipId }
//    }
//    
//    // GET User through membership (chain lookup)
//    var authorUser: User? {
//        guard let membership = authorMembership else { return nil }
//        return User.sampleUsers.first { $0.id == membership.userId }
//    }
//    
//    // GET Role from membership (guild-specific role)
//    var authorRole: UserRole? {
//        authorMembership?.roleInGuild
//    }
//    
//    // GET Name from user
//    var authorName: String? {
//        authorUser?.name
//    }
//    
//    // GET guild reputation from user
//    var authorGuildReputation: Int? {
//        authorMembership?.reputation
//    }
//}
//
//
//// CHATROOM
//extension Chatroom {
//    static let sampleChatrooms: [Chatroom] = [
//        
//        Chatroom(name: "General Discussion", guildId: GuildIDs.kaosGuild ,memberCount: 42, isActive: true, lastMessage: "Great analysis on BTC!"),
//        Chatroom(name: "Trading Talk", guildId: GuildIDs.kaosGuild , memberCount: 28, isActive: true, lastMessage: "AAPL looking bullish"),
//        Chatroom(name: "Market Analysis", guildId: GuildIDs.kaosGuild , memberCount: 15, isActive: false, lastMessage: "Chart patterns forming"),
//        Chatroom(name: "Off Topic", guildId: GuildIDs.kaosGuild , memberCount: 8, isActive: false, lastMessage: "Anyone watching the game?"),
//        Chatroom(name: "Announcements", guildId: GuildIDs.kaosGuild , memberCount: 52, isActive: false, lastMessage: "New guild event tomorrow!"),
//    ]
//}
//
//// CHATROOM MESSAGES
//extension ChatroomMessage {
//    static let sampleChatroomMessages: [ChatroomMessage] = [
//        // General Discussion - Morning conversation
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[0].id,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "Good morning everyone! Markets looking interesting today",
//            createdAt: Date().addingTimeInterval(-7200)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[0].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Morning! Yeah I'm watching SPY closely today 📊",
//            createdAt: Date().addingTimeInterval(-7140)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[0].id,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "SPY gapping up premarket 📈",
//            createdAt: Date().addingTimeInterval(-7080)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[0].id,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "I'm watching NVDA closely today",
//            createdAt: Date().addingTimeInterval(-7020)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[0].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "NVDA has been on fire! What's everyone's target?",
//            createdAt: Date().addingTimeInterval(-6960)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[0].id,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "Looking for a break above 875. Stop at 860",
//            createdAt: Date().addingTimeInterval(-6900)
//        ),
//        
//        // Trading Talk - Active discussion
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.marketGuruKaos,
//            content: "BTC just broke 45k resistance! 🚀",
//            createdAt: Date().addingTimeInterval(-3600)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.stockHawkKaos,
//            content: "Finally! Been waiting for this move",
//            createdAt: Date().addingTimeInterval(-3540)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Just entered at 45.2k with a tight stop at 44.5k",
//            createdAt: Date().addingTimeInterval(-3480)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Smart entry. Next target is 47k",
//            createdAt: Date().addingTimeInterval(-3420)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Thanks! Aiming for 47k 🎯",
//            createdAt: Date().addingTimeInterval(-3360)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Volume looks good on this breakout",
//            createdAt: Date().addingTimeInterval(-3300)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "ETH following along nicely too",
//            createdAt: Date().addingTimeInterval(-3240)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "ETH could be the next mover. Watching 2800 level",
//            createdAt: Date().addingTimeInterval(-3180)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Alts are waking up 👀",
//            createdAt: Date().addingTimeInterval(-3120)
//        ),
//        
//        // Market Analysis - Technical discussion
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[2].id,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Looking at the 4H chart, we have a clear cup and handle forming on SPY",
//            createdAt: Date().addingTimeInterval(-5400)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[2].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Good spot! The handle is testing perfectly",
//            createdAt: Date().addingTimeInterval(-5340)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[2].id,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "RSI showing bullish divergence on the daily",
//            createdAt: Date().addingTimeInterval(-5280)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[2].id,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Anyone watching the VIX? It's been unusually quiet",
//            createdAt: Date().addingTimeInterval(-5220)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[2].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Low VIX = complacency. Could see a spike soon",
//            createdAt: Date().addingTimeInterval(-5160)
//        ),
//        
//        // More recent Trading Talk messages
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "TSLA breaking out of consolidation pattern",
//            createdAt: Date().addingTimeInterval(-600)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.stockHawkKaos,
//            content: "Volume is huge! This could run",
//            createdAt: Date().addingTimeInterval(-540)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Watching 250 level closely. Break above and we're golden 🚀",
//            createdAt: Date().addingTimeInterval(-480)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Exactly! 250 is key resistance",
//            createdAt: Date().addingTimeInterval(-420)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.marketGuruKaos,
//            content: "Options flow showing heavy call buying",
//            createdAt: Date().addingTimeInterval(-360)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Smart money loading up! I'm in at 248.5 💰",
//            createdAt: Date().addingTimeInterval(-300)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Nice entry! Target 260?",
//            createdAt: Date().addingTimeInterval(-240)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Yep, targeting 260. Stop at 245",
//            createdAt: Date().addingTimeInterval(-180)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Risk/reward looks solid 👍",
//            createdAt: Date().addingTimeInterval(-120)
//        ),
//        ChatroomMessage(
//            roomId: Chatroom.sampleChatrooms[1].id,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Thanks! Let's see how this plays out 📈",
//            createdAt: Date().addingTimeInterval(-60)
//        ),
//    ]
//}
//
//// MARK: - Guild Model
//struct Guild: Identifiable, Codable, Equatable {
//    let id: UUID
//    let name: String
//    let description: String
//    let reputation: Int
//    let accuracy: Int
//    let owner: UUID
//    let dateCreated: Date
//    
//    
//    init(
//        id: UUID = UUID(),
//        name: String,
//        description: String = "No description",
//        reputation: Int = 0,
//        accuracy: Int = 0,
//        owner: UUID,
//        dateCreated: Date
//        
//    ) {
//        self.id = id
//        self.name = name
//        self.description = description
//        self.reputation = reputation
//        self.accuracy = accuracy
//        self.owner = owner
//        self.dateCreated = dateCreated
//        
//    }
//    // Convenience lookup using sample users (replace with real data source in app layer)
//    var authorUser: User? {
//        User.sampleUsers.first { $0.id == owner }
//    }
//    var authorRole: UserRole? { authorUser?.role }
//    var authorName: String? { authorUser?.name }
//    var authorMembership: GuildMembership? {
//        GuildMembership.currentGuildMemberships.first { $0.userId == owner && $0.guildId == id }
//    }
//}
//
//
//// MARK: - Sample Memberships
//struct GuildMembership: Identifiable, Codable, Equatable {
//    let id: UUID
//    let guildId: UUID
//    let userId: UUID
//    let roleInGuild: UserRole
//    let dateJoined: Date
//    let reputation: Int
//    
//    init(
//        id: UUID = UUID(),
//        guildId: UUID,
//        userId: UUID,
//        roleInGuild: UserRole,
//        dateJoined: Date = Date(),
//        reputation: Int = 0
//    ) {
//        self.id = id
//        self.guildId = guildId
//        self.userId = userId
//        self.roleInGuild = roleInGuild
//        self.dateJoined = dateJoined
//        self.reputation = reputation
//    }
//    
//    // MARK: - Computed Properties
//    
//    // GET User from userId
//    var user: User? {
//        User.sampleUsers.first { $0.id == userId }
//    }
//    
//    // GET Guild from guildId
//    var guild: Guild? {
//        Guild.allGuilds.first { $0.id == guildId }
//    }
//    
//    // Convenience properties
//    var userName: String? {
//        user?.name
//    }
//    
//    var guildName: String? {
//        guild?.name
//    }
//    
//    var userGlobalReputation: Int? {
//        user?.globalReputation
//    }
//    
//    var isUserOnline: Bool {
//        user?.isOnline ?? false
//    }
//    
//    // Time-based helpers
//    var timeInGuild: String {
//        let formatter = RelativeDateTimeFormatter()
//        formatter.unitsStyle = .full
//        return formatter.localizedString(for: dateJoined, relativeTo: Date())
//    }
//    
//    var daysInGuild: Int {
//        Calendar.current.dateComponents([.day], from: dateJoined, to: Date()).day ?? 0
//    }
//}
//
//
//// MARK: - User Friends Model
//struct GuildFriends: Identifiable, Codable, Equatable {
//    var id: UUID
//    var userID: UUID
//    var friendID: UUID
//    var dateFriendAdded: Date
//    
//    init(
//        id: UUID = UUID(),
//        userID: UUID,
//        friendID: UUID,
//        dateFriendAdded: Date = Date()
//    ) {
//        self.id = id
//        self.userID = userID
//        self.friendID = friendID
//        self.dateFriendAdded = dateFriendAdded
//    }
//}
//
//
//
//// MARK: - Announcement Models
//struct GuildAnnouncement: Identifiable, Codable, Equatable {
//    let id: UUID
//    let guildId: UUID
//    let membershipId: UUID
//    let title: String
//    let content: String
//    let postedAt: Date
//    let isImportant: Bool
//    let readBy: Set<UUID>
//    
//    // Custom initializer with defaults
//    init(
//        id: UUID = UUID(),
//        guildId: UUID,
//        membershipId: UUID,
//        title: String,
//        content: String,
//        postedAt: Date,
//        isImportant: Bool,
//        readBy: Set<UUID> = []
//    ) {
//        self.id = id
//        self.guildId = guildId
//        self.membershipId = membershipId
//        self.title = title
//        self.content = content
//        self.postedAt = postedAt
//        self.isImportant = isImportant
//        self.readBy = readBy
//    }
//    
//    // Computed properties for display
//    var timeAgo: String {
//        let formatter = RelativeDateTimeFormatter()
//        formatter.unitsStyle = .abbreviated
//        return formatter.localizedString(for: postedAt, relativeTo: Date())
//    }
//    
//    var preview: String {
//        let maxLength = 100
//        if content.count > maxLength {
//            return String(content.prefix(maxLength)) + "..."
//        }
//        return content
//    }
//    
//    // GET Guild
//    var announcementGuild: Guild? {
//        Guild.allGuilds.first { $0.id == guildId }
//    }
//    
//    // GET Membership
//    var authorMembership: GuildMembership? {
//        GuildMembership.currentGuildMemberships.first { $0.id == membershipId }
//    }
//    
//    // GET User through membership (chain lookup)
//    var authorUser: User? {
//        guard let membership = authorMembership else { return nil }
//        return User.sampleUsers.first { $0.id == membership.userId }
//    }
//    
//    // GET Role from membership (guild-specific role)
//    var authorRole: UserRole? {
//        authorMembership?.roleInGuild
//    }
//    
//    // GET Name from user
//    var authorName: String? {
//        authorUser?.name
//    }
//    
//    // GET guild reputation from user
//    var authorGuildReputation: Int? {
//        authorMembership?.reputation
//    }
//}
//
//
//// MARK: - Guild Event Model
//struct GuildEvent: Identifiable, Codable, Equatable {
//    let id: UUID
//    let guildId: UUID
//    let authorMembershipId: UUID
//    let title: String
//    let content: String
//    let postedAt: Date
//    let eventDate: Date
//    let isImportant: Bool
//    let noAttending: Int
//    let readBy: Set<UUID>
//    
//    init(
//        id: UUID = UUID(),
//        guildId: UUID,
//        authorMembershipId: UUID,
//        title: String,
//        content: String,
//        postedAt: Date,
//        eventDate: Date,
//        isImportant: Bool,
//        noAttending: Int,
//        readBy: Set<UUID> = []
//    ) {
//        self.id = id
//        self.guildId = guildId
//        self.authorMembershipId = authorMembershipId
//        self.title = title
//        self.content = content
//        self.postedAt = postedAt
//        self.eventDate = eventDate
//        self.isImportant = isImportant
//        self.noAttending = noAttending
//        self.readBy = readBy
//    }
//    
//    // Computed properties for display
//    var timeAgo: String {
//        let formatter = RelativeDateTimeFormatter()
//        formatter.unitsStyle = .abbreviated
//        return formatter.localizedString(for: postedAt, relativeTo: Date())
//    }
//    
//    var preview: String {
//        let maxLength = 100
//        if content.count > maxLength {
//            return String(content.prefix(maxLength)) + "..."
//        }
//        return content
//    }
//    
//    // GET Guild
//    var eventGuild: Guild? {
//        Guild.allGuilds.first { $0.id == guildId }
//    }
//    
//    // GET Membership
//    var authorMembership: GuildMembership? {
//        GuildMembership.currentGuildMemberships.first { $0.id == authorMembershipId }
//    }
//    
//    // GET User through membership (chain lookup)
//    var authorUser: User? {
//        guard let membership = authorMembership else { return nil }
//        return User.sampleUsers.first { $0.id == membership.userId }
//    }
//    
//    // GET Role from membership (guild-specific role)
//    var authorRole: UserRole? {
//        authorMembership?.roleInGuild
//    }
//    
//    // GET Name from user
//    var authorName: String? {
//        authorUser?.name
//    }
//}
//
//
//
//// MARK: - Guild Watchlist
//struct GuildWatchlist: Identifiable, Codable, Equatable {
//    let id: UUID
//    let guildId: UUID
//    let authorMembershipId: UUID
//    let name: String
//    let dateCreated: Date
//    var symbols: [UUID]
//
//    init(
//        id: UUID = UUID(),
//        guildId: UUID,
//        authorMembershipId: UUID,
//        name: String,
//        dateCreated: Date = Date(),
//        symbols: [UUID] = []
//    ) {
//        self.id = id
//        self.guildId = guildId
//        self.authorMembershipId = authorMembershipId
//        self.name = name
//        self.dateCreated = dateCreated
//        self.symbols = symbols
//    }
//    
//    // GET Guild
//    var currentGuild: Guild? {
//        Guild.allGuilds.first { $0.id == guildId }
//    }
//    
//    // GET Membership
//    var authorMembership: GuildMembership? {
//        GuildMembership.currentGuildMemberships.first { $0.id == authorMembershipId }
//    }
//    
//    // GET User through membership (chain lookup)
//    var authorUser: User? {
//        guard let membership = authorMembership else { return nil }
//        return User.sampleUsers.first { $0.id == membership.userId }
//    }
//    
//    // GET Role from membership (guild-specific role)
//    var authorRole: UserRole? {
//        authorMembership?.roleInGuild
//    }
//    
//    // GET Name from user
//    var authorName: String? {
//        authorUser?.name
//    }
//    
//    // Symbol helpers
//    var firstWatchlistSymbol: Symbol? {
//        Symbol.sampleSymbol.first { symbols.contains($0.id) }
//    }
//    
//    var symbolObjects: [Symbol] {
//        symbols.compactMap { symbolID in
//            Symbol.sampleSymbol.first(where: { $0.id == symbolID })
//        }
//    }
//}
//
//
//
//
//
//// MARK: - SAMPLE DATA
//
//
//
//
//struct GuildIDs{
//    static let kaosGuild = UUID()
//    static let megaGuild = UUID()
//}
//
//
//
//// MARK: -  Sample Guild
//
//extension Guild{
//    static let allGuilds: [Guild] = [
//        Guild(
//            id: GuildIDs.kaosGuild,
//            name: "KAOS",
//            description: "A great description of the kaos guild",
//            reputation: 1293,
//            accuracy: 34,
//            owner: UserIDs.seanPain,
//            dateCreated: Date().addingTimeInterval(-3600)
//    
//        ),
//        Guild(
//            id: GuildIDs.megaGuild,
//            name: "MEGA",
//            description: "A great description of the kaos guild",
//            reputation: 12312,
//            accuracy: 43,
//            owner: UserIDs.bullRunner,
//            dateCreated: Date().addingTimeInterval(-3600)
// 
//        )
//    ]
//    
//}
//
//
//struct MembershipIDs {
//    static let currentUserKaos = UUID()
//    static let seanPainKaos = UUID()
//    static let tradeMasterKaos = UUID()
//    static let bullRunnerKaos = UUID()
//    static let stockHawkKaos = UUID()
//    static let nightOwlKaos = UUID()
//    static let chartWizardMega = UUID()
//    static let marketGuruMega = UUID()
//    static let oldFriendMega = UUID()
//    static let quietInvestorMega = UUID()
//    static let chartWizardKaos = UUID()
//    static let marketGuruKaos = UUID()
//}
//
//extension GuildMembership {
//    
//    // KAOS Guild members
//    static let currentGuildMemberships: [GuildMembership] = [
//        
//        GuildMembership(
//            id: MembershipIDs.currentUserKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.currentUser,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*30),
//            reputation: 234
//        ),
//        GuildMembership(
//            id: MembershipIDs.seanPainKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.seanPain,
//            roleInGuild: .moderator,
//            dateJoined: Date().addingTimeInterval(-3600*24*60),
//            reputation: 6
//        ),
//        GuildMembership(
//            id: MembershipIDs.tradeMasterKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.tradeMaster,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*15),
//            reputation: 345
//        ),
//        GuildMembership(
//            id: MembershipIDs.bullRunnerKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.bullRunner,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*7),
//            reputation: 45
//        ),
//        GuildMembership(
//            id: MembershipIDs.stockHawkKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.stockHawk,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*3),
//            reputation: 567
//        ),
//        GuildMembership(
//            id: MembershipIDs.nightOwlKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.nightOwl,
//            roleInGuild: .admin,
//            dateJoined: Date().addingTimeInterval(-3600*24*45),
//            reputation: 234
//        ),
//        GuildMembership(
//            id: MembershipIDs.chartWizardKaos,  // ADD THIS
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.chartWizard,
//            roleInGuild: .moderator,
//            dateJoined: Date().addingTimeInterval(-3600*24*50),
//            reputation: 345
//        ),
//        GuildMembership(
//            id: MembershipIDs.marketGuruKaos,  // ADD THIS
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.marketGuru,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*25),
//            reputation: 56635
//        )
//    ]
//    
//    
//    // KAOS Guild members that are online and not friends
//    static let onlineNonFriendGuildMembers: [GuildMembership] = [
//        
//        GuildMembership(
//            id: MembershipIDs.seanPainKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.seanPain,
//            roleInGuild: .moderator,
//            dateJoined: Date().addingTimeInterval(-3600*24*60),
//            reputation: 6
//        ),
//        GuildMembership(
//            id: MembershipIDs.bullRunnerKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.bullRunner,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*7),
//            reputation: 45
//        ),
//        GuildMembership(
//            id: MembershipIDs.stockHawkKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.stockHawk,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*3),
//            reputation: 567
//        ),
//        GuildMembership(
//            id: MembershipIDs.marketGuruKaos,  // ADD THIS
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.marketGuru,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*25),
//            reputation: 56635
//        )
//    ]
//    
//    
//    // KAOS Guild members that are offline and not friends
//    static let offlineNonFriendGuildMembers: [GuildMembership] = [
//        
//        GuildMembership(
//            id: MembershipIDs.chartWizardKaos,  // ADD THIS
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.chartWizard,
//            roleInGuild: .moderator,
//            dateJoined: Date().addingTimeInterval(-3600*24*50),
//            reputation: 345
//        )
//    ]
//    
//    // KAOS Guild members that are offline and not friends
//    static let friendGuildMembers: [GuildMembership] = [
//        
//        GuildMembership(
//            id: MembershipIDs.nightOwlKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.nightOwl,
//            roleInGuild: .admin,
//            dateJoined: Date().addingTimeInterval(-3600*24*45),
//            reputation: 234
//        ),
//        GuildMembership(
//            id: MembershipIDs.tradeMasterKaos,
//            guildId: GuildIDs.kaosGuild,
//            userId: UserIDs.tradeMaster,
//            roleInGuild: .member,
//            dateJoined: Date().addingTimeInterval(-3600*24*15),
//            reputation: 345
//        )
//    ]
//    
//    
//}
//
//
//
//// MARK: - Guild Friends
//extension GuildFriends{
//    static let guildFriends: [GuildFriends] = [
//        GuildFriends(userID: UserIDs.currentUser, friendID: UserIDs.nightOwl, dateFriendAdded: Date().addingTimeInterval(-7200)),
//        GuildFriends(userID: UserIDs.currentUser, friendID: UserIDs.tradeMaster, dateFriendAdded: Date().addingTimeInterval(-7200))
//    ]
//}
//
//
//
//
//// MARK: - Guild Announcements
//// Note: GuildUser sample data removed, reference User.sampleUsers instead
//extension GuildAnnouncement {
//    static let guildAnnouncements: [GuildAnnouncement] = [
//        GuildAnnouncement(
//            guildId: GuildIDs.kaosGuild,
//            membershipId: MembershipIDs.nightOwlKaos,  // nightOwl is admin in KAOS
//            title: "New Trading Tournament Announced",
//            content: "We're excited to announce our biggest trading tournament yet! Starting next Monday, all guild members can participate in a week-long competition to see who can achieve the highest returns.\n\nPrizes include:\n• 1st Place: 1000 reputation points + Special badge\n• 2nd Place: 500 reputation points\n• 3rd Place: 250 reputation points\n\nAll trades must be documented with screenshots and verified by moderators. Good luck to everyone participating!",
//            postedAt: Date().addingTimeInterval(-3600), // 1 hour ago
//            isImportant: true
//        ),
//        GuildAnnouncement(
//            guildId: GuildIDs.kaosGuild,
//            membershipId: MembershipIDs.seanPainKaos,  // seanPain is moderator in KAOS
//            title: "Market Analysis Session - This Friday",
//            content: "Join us this Friday at 7 PM EST for our weekly market analysis session. We'll be reviewing the latest market trends, discussing upcoming earnings reports, and sharing trading strategies.\n\nTopics to cover:\n• SPY technical analysis\n• Earnings plays for next week\n• Crypto market outlook\n• Q&A session\n\nAll guild members are welcome to join and share their insights!",
//            postedAt: Date().addingTimeInterval(-7200), // 2 hours ago
//            isImportant: false
//        ),
//        GuildAnnouncement(
//            guildId: GuildIDs.kaosGuild,
//            membershipId: MembershipIDs.currentUserKaos,  // Current user posting
//            title: "New Member Welcome",
//            content: "Hey everyone! Just wanted to introduce myself. Looking forward to learning and sharing trading strategies with you all. Let's make some profitable trades together! 📈",
//            postedAt: Date().addingTimeInterval(-28800), // 8 hours ago
//            isImportant: false
//        )
//    ]
//}
//
//// EVENTS
//extension GuildEvent {
//    static let guildEvents: [GuildEvent] = [
//        GuildEvent(
//            guildId: GuildIDs.kaosGuild,
//            authorMembershipId: MembershipIDs.nightOwlKaos,
//            title: "Trading Tournament - Week 1",
//            content: "Join us for our first weekly trading tournament! Compete with guild members to see who can achieve the best risk-adjusted returns. Top 3 performers win reputation points and badges. All trades must be documented in the #trades channel.",
//            postedAt: Date().addingTimeInterval(-3600), // 1 hour ago
//            eventDate: Date().addingTimeInterval(86400 * 3), // 3 days from now
//            isImportant: true,
//            noAttending: 34
//        ),
//        GuildEvent(
//            guildId: GuildIDs.kaosGuild,
//            authorMembershipId: MembershipIDs.seanPainKaos,
//            title: "Market Analysis Session",
//            content: "Weekly live market analysis session. We'll cover technical setups, upcoming earnings, and macro events. Bring your questions!",
//            postedAt: Date().addingTimeInterval(-7200), // 2 hours ago
//            eventDate: Date().addingTimeInterval(86400 * 5), // 5 days from now
//            isImportant: false,
//            noAttending: 18
//        ),
//        GuildEvent(
//            guildId: GuildIDs.kaosGuild,
//            authorMembershipId: MembershipIDs.currentUserKaos,
//            title: "Beginner Trading Q&A",
//            content: "Open Q&A session for new traders. No question is too basic! Come learn about chart reading, risk management, and position sizing.",
//            postedAt: Date().addingTimeInterval(-14400), // 4 hours ago
//            eventDate: Date().addingTimeInterval(86400 * 2), // 2 days from now
//            isImportant: false,
//            noAttending: 12
//        )
//    ]
//}
//
//
//// EVENTS
//extension GuildWatchlist {
//    static let guildWatchlist: [GuildWatchlist] = [
//        GuildWatchlist(
//            guildId: GuildIDs.kaosGuild,
//            authorMembershipId: MembershipIDs.nightOwlKaos,
//            name: "Main Watchlist",
//            dateCreated: Date().addingTimeInterval(-3600),
//            symbols: [SymbolIDs.eurusd, SymbolIDs.audusd, SymbolIDs.gold]
//        )
//    ]
//}
//
//
//// MARK: - Notification Type
//enum NotificationType: String, Codable {
//    case personal = "Personal"
//    case symbol = "Symbol"
//    
//}
//
//
//struct Notification: Identifiable, Codable, Equatable {
//    let id: UUID
//    let title: String
//    let category: NotificationType
//    let addedDate: Date
//    let userId: UUID
//    
//    
//    init(
//        id: UUID = UUID(),
//        title: String,
//        category: NotificationType,
//        addedDate: Date = Date(),
//        userId: UUID
//        
//        
//    ) {
//        self.id = id
//        self.title = title
//        self.category = category
//        self.addedDate = addedDate
//        self.userId = userId
//        
//    }
//}
//
//struct NotificationIDs {
//    static let not1 = UUID()
//    static let not2 = UUID()
//    static let not3 = UUID()
//
//}
//
//
//// Notifications
//extension Notification {
//    static let sampleNotifications: [Notification] = [
//        Notification(
//            id: NotificationIDs.not1,
//            title: "Rising EURUSD bet to look",
//            category: .symbol,
//            addedDate: Date().addingTimeInterval(-3600),
//            userId: UserIDs.seanPain
//        ),
//        
//        Notification(
//            id: NotificationIDs.not2,
//            title: "Youve been promoted to Pro",
//            category: .personal,
//            addedDate: Date().addingTimeInterval(-3600),
//            userId: UserIDs.nightOwl
//        ),
//        
//        Notification(
//            id: NotificationIDs.not3,
//            title: "Rising audusdfjasd bet to look",
//            category: .symbol,
//            addedDate: Date().addingTimeInterval(-3600),
//            userId: UserIDs.seanPain
//        )
//        
//        
//    ]
//}
//
//
//// Holds all the data collected during the multi-step signup wizard
//// We store this centrally in SignupCoordinator and pass via @Binding to each step view
//struct SignupData {
//    var name: String = ""          // Full name
//    var email: String = ""         // Email address
//    var dob: Date = Date()         // Date of birth
//    var password: String = ""      // Password chosen by user
//    var username: String = ""      // Chosen username
//    var topics: [String] = []      // List of favorite topics selected by user
//    var guild: String = ""         // First guild user joins
//}
//
//
///// Enum representing each screen in the signup flow
//enum SignupStep: Hashable {
//    case accountInfo
//    case username
//    case basics
//    case guild
//    
//}
//
//
//// MARK: - User roles
//enum UserRole: String, Codable {
//    case member = "Member"
//    case admin = "Admin"
//    case moderator = "Moderator"
//}
//
//// MARK: - Core User Model (source of truth)
//// Represents an account/user in the system
//// Conforms to Codable for easy JSON parsing from network responses
//// Conforms to Identifiable for use in SwiftUI lists if needed
//struct User: Identifiable, Codable, Equatable {
//    var id: UUID                 // Unique identifier for the user
//    var name: String             // Display name/username
//    var email: String            // Email address
//    var globalReputation: Int          // Global reputation
//    var isOnline: Bool           // Presence
//    var status: String?          // Optional user status
//    var role: UserRole           // Global role (can differ per guild via GuildMembership)
//    
//    init(
//        id: UUID = UUID(),
//        name: String,
//        email: String,
//        globalReputation: Int = 0,
//        isOnline: Bool = false,
//        status: String? = nil,
//        role: UserRole = .member
//        
//    ){
//        self.id = id
//        self.name = name
//        self.email = email
//        self.globalReputation = globalReputation
//        self.isOnline = isOnline
//        self.status = status
//        self.role = role
//        
//    }
//    
//    
//}
//
////extension User {
////    static func friendIDs(for userId: UUID) -> Set<UUID> {
////        UserFriends.friendIDs(for: userId)
////    }
////}
//
//
//
//
////extension UserFriends {
////    // Get all friend IDs for a specific user
////    static func friendIDs(for userId: UUID) -> Set<UUID> {
////        Set(sampleFriends
////            .filter { $0.userID == userId }
////            .map { $0.friendID })
////    }
////
////    // Check if two users are friends
////    static func areFriends(userId: UUID, friendId: UUID) -> Bool {
////        sampleFriends.contains {
////            ($0.userID == userId && $0.friendID == friendId) ||
////            ($0.userID == friendId && $0.friendID == userId)
////        }
////    }
////}
//
//// MARK: - UI helpers for UserRole
//extension UserRole {
//    var foregroundColor: Color {
//        switch self {
//        case .admin: return .orange
//        case .moderator: return .blue
//        case .member: return AppColors.whiteText.opacity(0.7)
//        }
//    }
//    
//    var fontWeight: Font.Weight {
//        switch self {
//        case .admin: return .bold
//        case .moderator: return .bold
//        case .member: return .regular
//        }
//    }
//}
//
//// MARK: - Reusable User IDs
//struct UserIDs {
//    static let seanPain = UUID()
//    static let oldFriend = UUID()
//    static let tradeMaster = UUID()
//    static let chartWizard = UUID()
//    static let bullRunner = UUID()
//    static let marketGuru = UUID()
//    static let stockHawk = UUID()
//    static let sleepyTrader = UUID()
//    static let nightOwl = UUID()
//    static let quietInvestor = UUID()
//    static let currentUser = UUID()
//}
//
//// MARK: - SAMPLE DATA
//extension User {
//    static let sampleUsers: [User] = [
//        User(
//            id: UserIDs.currentUser,
//            name: "Alhennessey92",
//            email: "al@example.com",
//            globalReputation: 100,
//            isOnline: true,
//            status: "Active",
//            role: .member
//        ),
//        User(
//            id: UserIDs.seanPain,
//            name: "SeanPain",
//            email: "sean@example.com",
//            globalReputation: 50,
//            isOnline: true,
//            status: "Always online",
//            role: .moderator
//        ),
//        User(
//            id: UserIDs.tradeMaster,
//            name: "TradeMaster",
//            email: "trademaster@example.com",
//            globalReputation: 45,
//            isOnline: true,
//            status: "Trading AAPL",
//            role: .member
//        ),
//        User(
//            id: UserIDs.bullRunner,
//            name: "BullRunner",
//            email: "bullrunner@example.com",
//            globalReputation: 52,
//            isOnline: true,
//            status: nil,
//            role: .member
//        ),
//        User(
//            id: UserIDs.stockHawk,
//            name: "StockHawk",
//            email: "stockhawk@example.com",
//            globalReputation: 33,
//            isOnline: true,
//            status: nil,
//            role: .member
//        ),
//        User(
//            id: UserIDs.chartWizard,
//            name: "ChartWizard",
//            email: "chartwizard@example.com",
//            globalReputation: 38,
//            isOnline: false,
//            status: "Analyzing markets",
//            role: .admin
//        ),
//        User(
//            id: UserIDs.marketGuru,
//            name: "MarketGuru",
//            email: "marketguru@example.com",
//            globalReputation: 41,
//            isOnline: true,
//            status: "In a meeting",
//            role: .moderator
//        ),
//        User(
//            id: UserIDs.oldFriend,
//            name: "OldFriend",
//            email: "oldfriend@example.com",
//            globalReputation: 44,
//            isOnline: false,
//            status: "Busy IRL",
//            role: .member
//        ),
//        User(
//            id: UserIDs.nightOwl,
//            name: "NightOwl",
//            email: "nightowl@example.com",
//            globalReputation: 47,
//            isOnline: false,
//            status: "Away",
//            role: .admin
//        ),
//        User(
//            id: UserIDs.sleepyTrader,
//            name: "SleepyTrader",
//            email: "sleepy@example.com",
//            globalReputation: 29,
//            isOnline: false,
//            status: nil,
//            role: .member
//        ),
//        User(
//            id: UserIDs.quietInvestor,
//            name: "QuietInvestor",
//            email: "quiet@example.com",
//            globalReputation: 36,
//            isOnline: false,
//            status: nil,
//            role: .member
//        )
//    ]
//}
//
//
//// MARK: - UserDM Model
//struct UserDM: Identifiable, Codable, Equatable {
//    let id: UUID
//    let guildId: UUID
//    let userMembershipId: UUID // User ID the current user is talking to
//    let createdAt: Date
//    
//    init(
//        id: UUID = UUID(),
//        guildId: UUID,
//        userMembershipId: UUID,
//        createdAt: Date = Date()
//    ) {
//        // Always sort to maintain a stable order
//        self.id = id
//        self.guildId = guildId
//        self.userMembershipId = userMembershipId
//        self.createdAt = createdAt
//    }
//    
//    // MARK: - Derived convenience
//    var currentGuild: Guild? {
//        Guild.allGuilds.first { $0.id == guildId }
//    }
//    
//    var participantMembership: GuildMembership? {
//        GuildMembership.currentGuildMemberships.first { $0.id == userMembershipId }
//    }
//    
//    var participantUser: User? {
//        guard let membership = participantMembership else { return nil }
//        return User.sampleUsers.first { $0.id == membership.userId }
//    }
//
//    // GET Name from user
//    var participantName: String? {
//        participantUser?.name
//    }
//    
//    // GET Role from membership (guild-specific role)
//    var participantRole: UserRole? {
//        participantMembership?.roleInGuild
//    }
//    
//    // GET guild reputation from user
//    var participantGuildReputation: Int? {
//        participantMembership?.reputation
//    }
//}
//
//
//// MARK: - UserDM Message Model
//struct UserDMMessage: Identifiable, Codable, Equatable {
//    let id: UUID
//    let threadId: UUID // DM ID
//    let senderMembershipId: UUID
//    let content: String
//    let createdAt: Date
//    var isRead: Bool = false
//    
//    init(
//        id: UUID = UUID(),
//        threadId: UUID,
//        senderMembershipId: UUID,
//        content: String,
//        createdAt: Date,
//        isRead: Bool = false
//    ){
//        self.id = id
//        self.threadId = threadId
//        self.senderMembershipId = senderMembershipId
//        self.content = content
//        self.createdAt = createdAt
//        self.isRead = isRead
//    }
//    
//    var timeAgo: String {
//        let formatter = RelativeDateTimeFormatter()
//        formatter.unitsStyle = .abbreviated
//        return formatter.localizedString(for: createdAt, relativeTo: Date())
//    }
//    
//    var thread: UserDM? {
//        UserDM.userDMs.first { $0.id == threadId }
//    }
//    
//    var senderMembership: GuildMembership? {
//        GuildMembership.currentGuildMemberships.first { $0.id == senderMembershipId }
//    }
//    
//    var senderUser: User? {
//        guard let membership = senderMembership else { return nil }
//        return User.sampleUsers.first { $0.id == membership.userId }
//    }
//}
//
////struct UserIDs {
////    static let seanPain = UUID()
////    static let oldFriend = UUID()
////    static let tradeMaster = UUID()
////    static let chartWizard = UUID()
////    static let bullRunner = UUID()
////    static let marketGuru = UUID()
////    static let stockHawk = UUID()
////    static let sleepyTrader = UUID()
////    static let nightOwl = UUID()
////    static let quietInvestor = UUID()
////    static let currentUser = UUID()
////}
//
//struct DMIDs{
//        static let DMseanPain = UUID()
//        static let DMoldFriend = UUID()
//        static let DMtradeMaster = UUID()
//        static let DMchartWizard = UUID()
//        static let DMbullRunner = UUID()
//        static let DMmarketGuru = UUID()
//        static let DMstockHawk = UUID()
//        static let DMsleepyTrader = UUID()
//        static let DMnightOwl = UUID()
//        static let DMquietInvestor = UUID()
//
//    
//}
//
//// MARK: - UserDM Sample Data
//extension UserDM {
//    
//    /// Find existing DM with this membership, or create a new one
//    /// Simulates: GET /api/dms?membershipId={id} or POST /api/dms
//    static func find(with membership: GuildMembership) -> UserDM? {
//        return UserDM.userDMs.first(where: { $0.userMembershipId == membership.id })
//    }
//    
//    
//    static let userDMs: [UserDM] = [
//        UserDM(
//            id: DMIDs.DMseanPain,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.seanPainKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMbullRunner,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.bullRunnerKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMstockHawk,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.stockHawkKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMmarketGuru,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.marketGuruKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMchartWizard,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.chartWizardKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMnightOwl,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.nightOwlKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMtradeMaster,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.tradeMasterKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        )
//    ]
//    
//    // KAOS Guild DMs that are online and not friends
//    static let onlineNonFriendGuildDMs: [UserDM] = [
//        
//        UserDM(
//            id: DMIDs.DMseanPain,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.seanPainKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMbullRunner,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.bullRunnerKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMstockHawk,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.stockHawkKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMmarketGuru,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.marketGuruKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        )
//    ]
//    
//    
//    // KAOS Guild DMs that are offline and not friends
//    static let offlineNonFriendGuildDMs: [UserDM] = [
//        
//        UserDM(
//            id: DMIDs.DMchartWizard,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.chartWizardKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        )
//    ]
//    
//    // KAOS Guild DMs for friends
//    static let friendGuildDMs: [UserDM] = [
//        
//        UserDM(
//            id: DMIDs.DMnightOwl,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.nightOwlKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        ),
//        UserDM(
//            id: DMIDs.DMtradeMaster,
//            guildId: GuildIDs.kaosGuild,
//            userMembershipId: MembershipIDs.tradeMasterKaos,
//            createdAt: Date().addingTimeInterval(-86400 * 5)
//        )
//    ]
//}
//
//
//
//// MARK: - Extended Sample DM Messages
//extension UserDMMessage {
//    static let userDMMessages: [UserDMMessage] = [
//        
//        // MARK: - Thread 1: CurrentUser ↔️ SeanPain (Most Recent Activity - 30 min ago)
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Hey! Did you see the tournament bracket?",
//            createdAt: Date().addingTimeInterval(-7200),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Yeah just checked it out! We're in different groups 😄",
//            createdAt: Date().addingTimeInterval(-7140),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Perfect! May the best trader win 🏆",
//            createdAt: Date().addingTimeInterval(-7080),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Absolutely! What's your strategy for the first round?",
//            createdAt: Date().addingTimeInterval(-7020),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Focusing on crypto pairs. I think BTC and ETH will have good volatility",
//            createdAt: Date().addingTimeInterval(-6960),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Smart. I'm going with tech stocks - NVDA, TSLA, AAPL",
//            createdAt: Date().addingTimeInterval(-6900),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Nice picks. NVDA has been on fire lately 🔥",
//            createdAt: Date().addingTimeInterval(-6840),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Exactly! The AI hype is real. Target is 900 by next week",
//            createdAt: Date().addingTimeInterval(-6780),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Bold prediction! I like it. What's your stop loss?",
//            createdAt: Date().addingTimeInterval(-3600),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "850 - keeping it tight. Risk management is key 📊",
//            createdAt: Date().addingTimeInterval(-3540),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMseanPain,
//            senderMembershipId: MembershipIDs.seanPainKaos,
//            content: "Good thinking. BTW, are you going to the guild meetup next Friday?",
//            createdAt: Date().addingTimeInterval(-1800),
//            isRead: false
//        ),
//        
//        // MARK: - Thread 2: CurrentUser ↔️ TradeMaster (Recent - 1 hour ago)
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "Quick question about the BTC setup",
//            createdAt: Date().addingTimeInterval(-14400),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Sure, what's up?",
//            createdAt: Date().addingTimeInterval(-14340),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "I'm seeing a potential head and shoulders forming on the 4H. What do you think?",
//            createdAt: Date().addingTimeInterval(-14280),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Let me check... yeah I see it too! Right shoulder is forming now",
//            createdAt: Date().addingTimeInterval(-14220),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "Exactly. I'm thinking of shorting if it breaks the neckline",
//            createdAt: Date().addingTimeInterval(-14160),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "That's a solid play. What's your entry point?",
//            createdAt: Date().addingTimeInterval(-14100),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "44.8k if it breaks down. Stop at 45.5k",
//            createdAt: Date().addingTimeInterval(-14040),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Nice tight stop. Target?",
//            createdAt: Date().addingTimeInterval(-13980),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "First target 43.5k, second at 42k. Good R:R 👌",
//            createdAt: Date().addingTimeInterval(-13920),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Love it. Keep me posted if you enter!",
//            createdAt: Date().addingTimeInterval(-13860),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "Will do! Also, did you see the guild leaderboard?",
//            createdAt: Date().addingTimeInterval(-10800),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Yeah! You're crushing it - 2nd place 🎉",
//            createdAt: Date().addingTimeInterval(-10740),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "Thanks! You're not far behind. Great accuracy this month",
//            createdAt: Date().addingTimeInterval(-10680),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Appreciate it! Been really focused on quality setups",
//            createdAt: Date().addingTimeInterval(-10620),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMtradeMaster,
//            senderMembershipId: MembershipIDs.tradeMasterKaos,
//            content: "It shows! Hey, I'm entering that BTC short now. Neckline just broke",
//            createdAt: Date().addingTimeInterval(-3600),
//            isRead: false
//        ),
//        
//        // MARK: - Thread 3: CurrentUser ↔️ ChartWizard (Active - 2 hours ago)
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Hey! Can you help me with some chart analysis?",
//            createdAt: Date().addingTimeInterval(-21600),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Of course! What are you looking at?",
//            createdAt: Date().addingTimeInterval(-21540),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "TSLA on the daily. Trying to figure out if this is a reversal or continuation pattern",
//            createdAt: Date().addingTimeInterval(-21480),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Let me pull it up... Okay, I see what you're looking at",
//            createdAt: Date().addingTimeInterval(-21420),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "That's a textbook ascending triangle. Bullish continuation imo",
//            createdAt: Date().addingTimeInterval(-21360),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "That's what I was thinking! So wait for breakout above 250?",
//            createdAt: Date().addingTimeInterval(-21300),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Exactly. Volume should spike on the breakout. That's your confirmation",
//            createdAt: Date().addingTimeInterval(-21240),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Perfect. I'll set an alert. Thanks for the second opinion! 🙏",
//            createdAt: Date().addingTimeInterval(-21180),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Anytime! Also check the RSI - it's been building nicely",
//            createdAt: Date().addingTimeInterval(-21120),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Good catch. No bearish divergence either 📈",
//            createdAt: Date().addingTimeInterval(-21060),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMchartWizard,
//            senderMembershipId: MembershipIDs.chartWizardKaos,
//            content: "Exactly. This could be a nice runner. Target around 265-270",
//            createdAt: Date().addingTimeInterval(-7200),
//            isRead: false
//        ),
//        
//        // MARK: - Thread 4: CurrentUser ↔️ BullRunner (Recent - 45 min ago)
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "Yo! NVDA just broke 875! 🚀",
//            createdAt: Date().addingTimeInterval(-10800),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "I SAW! Finally! Been waiting for this 💪",
//            createdAt: Date().addingTimeInterval(-10740),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "Did you get in?",
//            createdAt: Date().addingTimeInterval(-10680),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Yep! Entered at 876. Stop at 870",
//            createdAt: Date().addingTimeInterval(-10620),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "Nice timing! I got in at 874.5. Riding this to 900 🎯",
//            createdAt: Date().addingTimeInterval(-10560),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Same target! Volume looks insane right now",
//            createdAt: Date().addingTimeInterval(-10500),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "For real. This is the AI rally everyone's been talking about",
//            createdAt: Date().addingTimeInterval(-10440),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Absolutely. Jensen's presentation tomorrow should add fuel ⛽",
//            createdAt: Date().addingTimeInterval(-10380),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMbullRunner,
//            senderMembershipId: MembershipIDs.bullRunnerKaos,
//            content: "Oh yeah! Forgot about that. Could catalyst to 900+",
//            createdAt: Date().addingTimeInterval(-2700),
//            isRead: false
//        ),
//        
//        // MARK: - Thread 5: CurrentUser ↔️ MarketGuru (Active - 3 hours ago)
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.marketGuruKaos,
//            content: "Have you been watching the macro news?",
//            createdAt: Date().addingTimeInterval(-28800),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Yeah, the Fed meeting is coming up. What's your take?",
//            createdAt: Date().addingTimeInterval(-28740),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.marketGuruKaos,
//            content: "I think they'll hold rates. Inflation data came in cooler than expected",
//            createdAt: Date().addingTimeInterval(-28680),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Agreed. That's bullish for risk assets",
//            createdAt: Date().addingTimeInterval(-28620),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.marketGuruKaos,
//            content: "Exactly my thinking. Loading up on tech calls",
//            createdAt: Date().addingTimeInterval(-28560),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Smart play. Which strikes are you looking at?",
//            createdAt: Date().addingTimeInterval(-28500),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.marketGuruKaos,
//            content: "SPY 455 calls expiring next Friday. Good premium",
//            createdAt: Date().addingTimeInterval(-28440),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMmarketGuru,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Nice. I might join you on that one 🤔",
//            createdAt: Date().addingTimeInterval(-10800),
//            isRead: false
//        ),
//        
//        // MARK: - Thread 6: CurrentUser ↔️ StockHawk (Recent - 4 hours ago)
//        UserDMMessage(
//            threadId: DMIDs.DMstockHawk,
//            senderMembershipId: MembershipIDs.stockHawkKaos,
//            content: "Dude, did you see AAPL earnings?",
//            createdAt: Date().addingTimeInterval(-43200),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMstockHawk,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Just checked - beat on both top and bottom line! 🍎",
//            createdAt: Date().addingTimeInterval(-43140),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMstockHawk,
//            senderMembershipId: MembershipIDs.stockHawkKaos,
//            content: "iPhone sales were through the roof. Up 15% YoY",
//            createdAt: Date().addingTimeInterval(-43080),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMstockHawk,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Services revenue looking good too. That's the real story",
//            createdAt: Date().addingTimeInterval(-43020),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMstockHawk,
//            senderMembershipId: MembershipIDs.stockHawkKaos,
//            content: "For sure. High margin recurring revenue 💰",
//            createdAt: Date().addingTimeInterval(-42960),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMstockHawk,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Thinking of adding to my position tomorrow",
//            createdAt: Date().addingTimeInterval(-42900),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMstockHawk,
//            senderMembershipId: MembershipIDs.stockHawkKaos,
//            content: "Same! Target price upgraded to 205 by multiple analysts",
//            createdAt: Date().addingTimeInterval(-14400),
//            isRead: false
//        ),
//        
//        // MARK: - Thread 7: CurrentUser ↔️ NightOwl (Most Recent - 20 min ago)
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Hey! Thanks for the guild watchlist suggestion earlier",
//            createdAt: Date().addingTimeInterval(-86400),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "No problem! Did we end up adding NVDA?",
//            createdAt: Date().addingTimeInterval(-86340),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Yes! ChartWizard approved it. Already seeing good movement",
//            createdAt: Date().addingTimeInterval(-86280),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Awesome! Great timing with the AI hype cycle",
//            createdAt: Date().addingTimeInterval(-86220),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Totally. What other stocks should we consider?",
//            createdAt: Date().addingTimeInterval(-86160),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Maybe AMD? It's been consolidating nicely",
//            createdAt: Date().addingTimeInterval(-86100),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Good call. I'll bring it up in the next guild meeting",
//            createdAt: Date().addingTimeInterval(-86040),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Sounds good! Also, are you entering the tournament?",
//            createdAt: Date().addingTimeInterval(-7200),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Definitely! Already registered. You?",
//            createdAt: Date().addingTimeInterval(-7140),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Yep! Should be fun. Good luck! 🍀",
//            createdAt: Date().addingTimeInterval(-7080),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "You too! May the best trader win 😄",
//            createdAt: Date().addingTimeInterval(-7020),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Absolutely! Hey quick question about that SPY setup...",
//            createdAt: Date().addingTimeInterval(-3600),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "What's up?",
//            createdAt: Date().addingTimeInterval(-3540),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "Do you think it'll break 450 this week?",
//            createdAt: Date().addingTimeInterval(-3480),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Looking at the technicals, I'd say 60/40 odds in favor",
//            createdAt: Date().addingTimeInterval(-3420),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.currentUserKaos,
//            content: "That's what I'm thinking too. FOMC meeting could be the catalyst",
//            createdAt: Date().addingTimeInterval(-3360),
//            isRead: true
//        ),
//        UserDMMessage(
//            threadId: DMIDs.DMnightOwl,
//            senderMembershipId: MembershipIDs.nightOwlKaos,
//            content: "Exactly. If they hold rates, we moon 🚀",
//            createdAt: Date().addingTimeInterval(-1200),
//            isRead: false
//        ),
//    ]
//}
