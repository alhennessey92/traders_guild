//
//  GuildUser.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//
import Foundation


// MARK: - Chatroom Model
struct Chatroom: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let guildId: UUID
    let memberCount: Int
    let isActive: Bool
    let lastMessage: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        guildId: UUID,
        memberCount: Int,
        isActive: Bool,
        lastMessage: String?
    ) {
        self.id = id
        self.name = name
        self.guildId = guildId
        self.memberCount = memberCount
        self.isActive = isActive
        self.lastMessage = lastMessage
    }
    var currentGuild: Guild? {
        Guild.allGuilds.first { $0.id == guildId }
    }
}

// MARK: - Chatroom Message Model
struct ChatroomMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let roomId: UUID
    let senderMembershipId: UUID // Handled as GuildMembership
    let content: String
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        roomId: UUID,
        senderMembershipId: UUID,
        content: String,
        createdAt: Date
    ){
        self.id = id
        self.roomId = roomId
        self.senderMembershipId = senderMembershipId
        self.content = content
        self.createdAt = createdAt
    }
    // Computed properties for display
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    var currentChatRoom: Chatroom? {
        Chatroom.sampleChatrooms.first { $0.id == roomId }
    }
    
    
    // GET Membership
    var authorMembership: GuildMembership? {
        GuildMembership.currentGuildMemberships.first { $0.id == senderMembershipId }
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


// CHATROOM
extension Chatroom {
    static let sampleChatrooms: [Chatroom] = [
        
        Chatroom(name: "General Discussion", guildId: GuildIDs.kaosGuild ,memberCount: 42, isActive: true, lastMessage: "Great analysis on BTC!"),
        Chatroom(name: "Trading Talk", guildId: GuildIDs.kaosGuild , memberCount: 28, isActive: true, lastMessage: "AAPL looking bullish"),
        Chatroom(name: "Market Analysis", guildId: GuildIDs.kaosGuild , memberCount: 15, isActive: false, lastMessage: "Chart patterns forming"),
        Chatroom(name: "Off Topic", guildId: GuildIDs.kaosGuild , memberCount: 8, isActive: false, lastMessage: "Anyone watching the game?"),
        Chatroom(name: "Announcements", guildId: GuildIDs.kaosGuild , memberCount: 52, isActive: false, lastMessage: "New guild event tomorrow!"),
    ]
}

// CHATROOM MESSAGES
extension ChatroomMessage {
    static let sampleChatroomMessages: [ChatroomMessage] = [
        // General Discussion - Morning conversation
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[0].id,
            senderMembershipId: MembershipIDs.tradeMasterKaos,
            content: "Good morning everyone! Markets looking interesting today",
            createdAt: Date().addingTimeInterval(-7200)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[0].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Morning! Yeah I'm watching SPY closely today 📊",
            createdAt: Date().addingTimeInterval(-7140)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[0].id,
            senderMembershipId: MembershipIDs.chartWizardKaos,
            content: "SPY gapping up premarket 📈",
            createdAt: Date().addingTimeInterval(-7080)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[0].id,
            senderMembershipId: MembershipIDs.bullRunnerKaos,
            content: "I'm watching NVDA closely today",
            createdAt: Date().addingTimeInterval(-7020)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[0].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "NVDA has been on fire! What's everyone's target?",
            createdAt: Date().addingTimeInterval(-6960)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[0].id,
            senderMembershipId: MembershipIDs.bullRunnerKaos,
            content: "Looking for a break above 875. Stop at 860",
            createdAt: Date().addingTimeInterval(-6900)
        ),
        
        // Trading Talk - Active discussion
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.marketGuruKaos,
            content: "BTC just broke 45k resistance! 🚀",
            createdAt: Date().addingTimeInterval(-3600)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.stockHawkKaos,
            content: "Finally! Been waiting for this move",
            createdAt: Date().addingTimeInterval(-3540)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Just entered at 45.2k with a tight stop at 44.5k",
            createdAt: Date().addingTimeInterval(-3480)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.chartWizardKaos,
            content: "Smart entry. Next target is 47k",
            createdAt: Date().addingTimeInterval(-3420)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Thanks! Aiming for 47k 🎯",
            createdAt: Date().addingTimeInterval(-3360)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.nightOwlKaos,
            content: "Volume looks good on this breakout",
            createdAt: Date().addingTimeInterval(-3300)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.bullRunnerKaos,
            content: "ETH following along nicely too",
            createdAt: Date().addingTimeInterval(-3240)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "ETH could be the next mover. Watching 2800 level",
            createdAt: Date().addingTimeInterval(-3180)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.seanPainKaos,
            content: "Alts are waking up 👀",
            createdAt: Date().addingTimeInterval(-3120)
        ),
        
        // Market Analysis - Technical discussion
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[2].id,
            senderMembershipId: MembershipIDs.chartWizardKaos,
            content: "Looking at the 4H chart, we have a clear cup and handle forming on SPY",
            createdAt: Date().addingTimeInterval(-5400)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[2].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Good spot! The handle is testing perfectly",
            createdAt: Date().addingTimeInterval(-5340)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[2].id,
            senderMembershipId: MembershipIDs.tradeMasterKaos,
            content: "RSI showing bullish divergence on the daily",
            createdAt: Date().addingTimeInterval(-5280)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[2].id,
            senderMembershipId: MembershipIDs.nightOwlKaos,
            content: "Anyone watching the VIX? It's been unusually quiet",
            createdAt: Date().addingTimeInterval(-5220)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[2].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Low VIX = complacency. Could see a spike soon",
            createdAt: Date().addingTimeInterval(-5160)
        ),
        
        // More recent Trading Talk messages
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.tradeMasterKaos,
            content: "TSLA breaking out of consolidation pattern",
            createdAt: Date().addingTimeInterval(-600)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.stockHawkKaos,
            content: "Volume is huge! This could run",
            createdAt: Date().addingTimeInterval(-540)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Watching 250 level closely. Break above and we're golden 🚀",
            createdAt: Date().addingTimeInterval(-480)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.chartWizardKaos,
            content: "Exactly! 250 is key resistance",
            createdAt: Date().addingTimeInterval(-420)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.marketGuruKaos,
            content: "Options flow showing heavy call buying",
            createdAt: Date().addingTimeInterval(-360)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Smart money loading up! I'm in at 248.5 💰",
            createdAt: Date().addingTimeInterval(-300)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.nightOwlKaos,
            content: "Nice entry! Target 260?",
            createdAt: Date().addingTimeInterval(-240)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Yep, targeting 260. Stop at 245",
            createdAt: Date().addingTimeInterval(-180)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.seanPainKaos,
            content: "Risk/reward looks solid 👍",
            createdAt: Date().addingTimeInterval(-120)
        ),
        ChatroomMessage(
            roomId: Chatroom.sampleChatrooms[1].id,
            senderMembershipId: MembershipIDs.currentUserKaos,
            content: "Thanks! Let's see how this plays out 📈",
            createdAt: Date().addingTimeInterval(-60)
        ),
    ]
}

