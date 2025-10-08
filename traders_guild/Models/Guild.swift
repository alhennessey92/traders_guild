//
//  Guild.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import Foundation
import SwiftUI


// MARK: - User roles
enum UserRole: String, Codable {
    case member = "Member"
    case admin = "Admin"
    case moderator = "Moderator"
}

// MARK: - UserRole UI Extensions such as color and weight
extension UserRole {
    var foregroundColor: Color {
        switch self {
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return AppColors.whiteText.opacity(0.7)
        }
    }
    
    var fontWeight: Font.Weight {
        switch self {
        case .admin: return .bold
        case .moderator: return .bold
        case .member: return .regular
        }
    }
}




// MARK: - User Model
struct GuildUser: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let reputation: Int
    let isOnline: Bool
    let status: String?
    let role: UserRole
    let newMessage: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        reputation: Int,
        isOnline: Bool,
        status: String?,
        role: UserRole,
        newMessage: Bool
    ) {
        self.id = id
        self.name = name
        self.reputation = reputation
        self.isOnline = isOnline
        self.status = status
        self.role = role
        self.newMessage = newMessage
    }
}
// MARK: - Announcement Models
struct GuildAnnouncement: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let content: String
    let author: String
    let authorRole: UserRole
    let postedAt: Date
    let isImportant: Bool
    let readBy: Set<UUID>
    
    // Custom initializer with defaults
    init(
        id: UUID = UUID(),           // Default for sample data
        title: String,
        content: String,
        author: String,
        authorRole: UserRole,
        postedAt: Date,
        isImportant: Bool,
        readBy: Set<UUID> = []       // Default for sample data
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.author = author
        self.authorRole = authorRole
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
}



// MARK: - Announcement Models
struct GuildEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let content: String
    let author: String
    let authorRole: UserRole
    let postedAt: Date
    let eventDate: Date
    let isImportant: Bool
    let noAttending: Int
    let readBy: Set<UUID>
    
    // Custom initializer with defaults
    init(
        id: UUID = UUID(),           // Default for sample data
        title: String,
        content: String,
        author: String,
        authorRole: UserRole,
        postedAt: Date,
        eventDate: Date,
        isImportant: Bool,
        noAttending: Int,
        readBy: Set<UUID> = []       // Default for sample data
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.author = author
        self.authorRole = authorRole
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
}








// MARK: - SAMPLE DATA


// MARK: - Reusable User IDs
struct UserIDs {
    static let seanPain = UUID()
    static let oldFriend = UUID()
    static let tradeMaster = UUID()
    static let chartWizard = UUID()
    static let bullRunner = UUID()
    static let marketGuru = UUID()
    static let stockHawk = UUID()
    static let sleepyTrader = UUID()
    static let nightOwl = UUID()
    static let quietInvestor = UUID()
}



// MARK: - Sample Data
extension GuildUser {
    static let sampleUsers: [GuildUser] = [
        // Online users
        GuildUser(
            id: UserIDs.seanPain,
            name: "SeanPain",
            reputation: 50,
            isOnline: true,
            status: "Always online",
            role: .moderator,
            newMessage: false
        ),
        GuildUser(
            id: UserIDs.tradeMaster,
            name: "TradeMaster",
            reputation: 45,
            isOnline: true,
            status: "Trading AAPL",
            role: .member,
            newMessage: false
        ),
        GuildUser(
            id: UserIDs.bullRunner,
            name: "BullRunner",
            reputation: 52,
            isOnline: true,
            status: nil,
            role: .member,
            newMessage: false
        ),
        GuildUser(
            id: UserIDs.stockHawk,
            name: "StockHawk",
            reputation: 33,
            isOnline: true,
            status: nil,
            role: .member,
            newMessage: true
        ),
        GuildUser(
            id: UserIDs.chartWizard,
            name: "ChartWizard",
            reputation: 38,
            isOnline: true,
            status: "Analyzing markets",
            role: .admin,
            newMessage: true
        ),
        GuildUser(
            id: UserIDs.marketGuru,
            name: "MarketGuru",
            reputation: 41,
            isOnline: true,
            status: "In a meeting",
            role: .moderator,
            newMessage: true
        ),
        
        // Offline users
        GuildUser(
            id: UserIDs.oldFriend,
            name: "OldFriend",
            reputation: 44,
            isOnline: false,
            status: "Busy IRL",
            role: .member,
            newMessage: true
        ),
        GuildUser(
            id: UserIDs.nightOwl,
            name: "NightOwl",
            reputation: 47,
            isOnline: false,
            status: "Away",
            role: .admin,
            newMessage: true
        ),
        GuildUser(
            id: UserIDs.sleepyTrader,
            name: "SleepyTrader",
            reputation: 29,
            isOnline: false,
            status: nil,
            role: .member,
            newMessage: true
        ),
        GuildUser(
            id: UserIDs.quietInvestor,
            name: "QuietInvestor",
            reputation: 36,
            isOnline: false,
            status: nil,
            role: .member,
            newMessage: false
        )
    ]
}


// ANNOUNCEMENTS
extension GuildAnnouncement {
    static let sampleGuildAnnouncment: [GuildAnnouncement] = [
        GuildAnnouncement(
            title: "New Trading Tournament Announced",
            content: "We're excited to announce our biggest trading tournament yet! Starting next Monday, all guild members can participate in a week-long competition to see who can achieve the highest returns.\n\nPrizes include:\n• 1st Place: 1000 reputation points + Special badge\n• 2nd Place: 500 reputation points\n• 3rd Place: 250 reputation points\n\nAll trades must be documented with screenshots and verified by moderators. Good luck to everyone participating!",
            author: "Guild Master",
            authorRole: .admin,
            postedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            isImportant: true
        ),
        GuildAnnouncement(
            title: "Market Analysis Session - This Friday",
            content: "Join us this Friday at 7 PM EST for our weekly market analysis session. We'll be reviewing the latest market trends, discussing upcoming earnings reports, and sharing trading strategies.\n\nTopics to cover:\n• SPY technical analysis\n• Earnings plays for next week\n• Crypto market outlook\n• Q&A session\n\nAll guild members are welcome to join and share their insights!",
            author: "ChartMaster",
            authorRole: .moderator,
            postedAt: Date().addingTimeInterval(-7200), // 2 hours ago
            isImportant: false
        ),
        GuildAnnouncement(
            title: "Guild Rules Update",
            content: "Please review the updated guild rules in the #rules channel. Key changes include:\n\n• Updated posting guidelines for trade ideas\n• New reputation system rules\n• Community conduct standards\n\nAll members are expected to follow these guidelines. Violations may result in temporary or permanent removal from the guild.",
            author: "Moderator Team",
            authorRole: .moderator,
            postedAt: Date().addingTimeInterval(-14400), // 4 hours ago
            isImportant: true
        ),
        GuildAnnouncement(
            title: "Weekly Leaderboard Results",
            content: "Congratulations to this week's top performers!\n\n🥇 TradeMaster - 85% win rate\n🥈 ChartWizard - 82% win rate\n🥉 BullRunner - 78% win rate\n\nGreat work everyone! Keep up the excellent trading and analysis. Remember, consistency is key in trading success.",
            author: "System",
            authorRole: .admin,
            postedAt: Date().addingTimeInterval(-21600), // 6 hours ago
            isImportant: false
        )
        
    ]
}





// EVENTS
extension GuildEvent {
    static let sampleGuildEvents: [GuildEvent] = [
        GuildEvent(
            title: "New Trading Tournament Event",
            content: "Big new event",
            author: "Guild Master",
            authorRole: .admin,
            postedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            eventDate: Date().addingTimeInterval(+50600),
            isImportant: true,
            noAttending: 34
        )
    ]
}
