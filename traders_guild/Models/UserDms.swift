////
////  UserDms.swift
////  traders_guild
////
////  Created by Al Hennessey on 19/10/2025.
////
//
//import Foundation
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
