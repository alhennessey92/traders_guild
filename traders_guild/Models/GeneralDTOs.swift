//
//  DTOs.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//

import Foundation
import SwiftUI


// ================================================================================================
// MARK: - SECTION 1: DATA TRANSFER OBJECTS (DTOs)
// ================================================================================================
// These replace your current models that do UUID lookups.
// Each DTO contains ALL the data needed for display - no lookups required!
// The backend does the heavy lifting of joining tables and formatting data.
// ================================================================================================

// MARK: - User Role Enum
/// Defines the permission hierarchy within guilds
/// This determines what actions a user can perform
enum MemberRole: String, Codable, CaseIterable {
    case member = "Member"          // Basic: can chat, view content, join events
    case moderator = "Moderator"    // Mid: can moderate chat, pin messages, create events
    case admin = "Admin"            // Full: can manage guild settings, kick members, delete guild
    
    /// Display-friendly name for UI
    var displayName: String {
        switch self {
        case .member: return "Member"
        case .moderator: return "Moderator"
        case .admin: return "Admin"
        }
    }
    
    /// Color for roles in UI
    var roleForegroundColor: Color {
        switch self {
        case .member: return .gray
        case .moderator: return .orange
        case .admin: return .red
        }
    }
    
    /// Font Weight for roles
    var roleFontWeight: Font.Weight {
        switch self {
        case .admin: return .bold
        case .moderator: return .bold
        case .member: return .regular
        }
    }
    
    /// Check if role has moderation permissions
    var canModerate: Bool {
        self == .moderator || self == .admin
    }
    
    /// Check if role has admin permissions
    var canAdmin: Bool {
        self == .admin
    }
    
    /// Returns the hierarchical level of the role (higher = more power)
    var hierarchyLevel: Int {
        switch self {
        case .admin: return 3
        case .moderator: return 2
        case .member: return 1
        }
    }
    
    /// Check if this role can delete a message from another role
    func canDelete(messageFrom authorRole: MemberRole, isOwnMessage: Bool) -> Bool {
        // Always can delete own messages
        if isOwnMessage {
            return true
        }
        
        // Can only delete if your role is higher than the author's role
        return self.hierarchyLevel > authorRole.hierarchyLevel
    }
}

// MARK: - Current User DTO
/// Represents the currently authenticated user
/// This is the user who is logged into the app
/// Stored in AppState and persisted to Keychain
/// Updated when: login, profile edit, reputation changes
struct CurrentUserDTO: Codable, Equatable {
    let id: UUID                    // Unique user ID from backend database
    let email: String               // User's email (used for authentication)
    let name: String                // Display name shown in UI (e.g., "John Developer")
    let username: String            // Unique handle without @ (e.g., "johndev")
    let avatarURL: String?          // Profile picture URL from CDN (nil = default avatar)
    let globalReputation: Int       // Total reputation across all guilds
   //let isPremium: Bool             // Premium subscription status (unlocks features)
    let notificationCount: Int      // Unread notifications for tab badge
    let unreadMessages: Int         // Total unread DMs for tab badge
    let guildMembership: GuildMembershipDTO // Users Guild Membership
    
    /// Formatted username with @ symbol for display
    var displayUsername: String {
        "@\(username)"
    }
    
    /// Check if user has any unread items
    var hasUnreadItems: Bool {
        notificationCount > 0 || unreadMessages > 0
    }
    
    /// Total badge count for app icon
    var totalBadgeCount: Int {
        notificationCount + unreadMessages
    }
}

// MARK: - Guild Member DTO
/// Represents any user within the TG global app
/// This DTO is EMBEDDED in other DTOs to avoid lookups
/// Contains everything needed to display a user in lists, chat, etc.
/// IMPORTANT: This is NOT the current user - it's for displaying other members
struct GlobalMemberDTO: Codable, Equatable, Identifiable {
    let id: UUID                    // User's unique ID (same across all guilds)
    let email: String               // User's email (used for authentication)
    let name: String                // Display name (e.g., "Alex Thompson")
    let username: String            // Unique handle without @ (e.g., "johndev")
    let avatarURL: String?          // Profile picture URL (nil = use default)
    let isOnline: Bool              // Real-time online status for presence indicator
    let globalReputation: Int       // Total reputation across entire platform
    // Need to add date of birth and topics
    

    
    
}

// MARK: - Guild Summary DTO
/// Lightweight guild representation for lists and references
/// Use this when you need basic guild info without full details
/// Example: showing mutual guilds, guild selector dropdown
struct GuildSummaryDTO: Codable, Equatable {
    let id: UUID                    // Guild's unique identifier
    let name: String                // Guild name (e.g., "KAOS)
    let memberCount: Int            // Current number of members
    let imageURL: String?           // Guild logo/banner URL (nil = default image)
    let reputation: Int             // Guild Reputation
    let owner: GuildMembershipDTO       // Guild Owner
    let isOpen: Bool                // Guild Status - Open/Close
    
    /// Formatted display with member count
    var displayName: String {
        "\(name) • \(memberCount) members"
    }
    
    /// Formatted member count for large numbers
    var formattedMemberCount: String {
        if memberCount > 1000 {
            return "\(memberCount / 1000)k members"
        }
        return "\(memberCount) members"
    }
    
    /// Text for new membership status
    var statusText: String {
        isOpen ? "Open" : "Closed"
    }
}

// MARK: - Guild DTO (Full)
/// Complete guild information for detail views
/// Contains everything about a guild including the current user's relationship to it
/// Used in: guild detail page, guild discovery, guild management
///
///  MAY ADAPT THIS TO OWNER:GUILDMEMBER TO GET ROLES ETC... BUT WILL BE RECURSIVE BECAUSE OF GUILD
struct GuildDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Guild's unique identifier from backend
    let name: String                // Guild name (e.g., "Tech Traders United")
    let description: String         // Detailed description of guild's purpose
    let reputation: Int             // Total combined reputation of all members
    let accuracy: Int               // Trading accuracy percentage (0-100)
    let memberCount: Int            // Current number of members
    let owner: GlobalMemberDTO       // EMBEDDED owner data (no lookup needed!)
    let ownerRole: MemberRole       // Owner Role
    let dateCreated: Date           // When guild was founded
    let imageURL: String?           // Guild logo/banner from CDN
    let isJoined: Bool              // Is current user a member? (personalized)
    let currentMemberRole: MemberRole?  // Current user's role IF member (nil = not member)
    let isOpen: Bool                // Guild Status - Open/Closed
    let membersOnline: Int          // No of users online
    
    /// Formatted creation date for display
    var formattedDate: String {
        dateCreated.formatted(date: .abbreviated, time: .omitted)
    }
    
    /// Human-readable reputation (1000 -> 1k)
    var reputationDisplay: String {
        if reputation > 1000 {
            return "\(reputation/1000)k"
        }
        return "\(reputation)"
    }
    
    /// Check if current user can post announcements
    var canPost: Bool {
        guard let role = currentMemberRole else { return false }
        return role.canModerate
    }
    
    /// Check if current user can manage guild
    var canManage: Bool {
        currentMemberRole?.canAdmin ?? false // If current member is admin return true else return false
    }
    
    /// Guild age in days
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: dateCreated, to: Date()).day ?? 0
    }
    
    /// Text for new membership status
    var statusText: String {
        isOpen ? "Open" : "Closed"
    }
}

// MARK: - Guild Statistics DTO
/// Lightweight guild representation for lists and references
/// Use this when you need basic guild info without full details
/// Example: showing mutual guilds, guild selector dropdown
struct GuildStatisticsDTO: Codable, Equatable {
    let id: UUID                    // Guild's unique identifier
    let name: String                // Guild name (e.g., "KAOS)
    let totalPredictions: Int            // Current number of members
    let correctPredictions: Int            // Current number of members
    let averageAccuracy: Int            // Current number of members
    let guildRank: Int            // Current number of members
    let newMembers: Int            // Current number of members
    let activeUsers: Int            // Current number of members
    let predictionsMade: Int            // Current number of members
    let reputationEarned: Int
    
    var totalPredictionsDisplay: String {
        
        return "\(totalPredictions)"
    }
    var correctPredictionsDisplay: String {
        
        return "\(correctPredictions)"
    }
    /// Human-readable reputation (1000 -> 1k)
    var averageAccuracyDisplay: String {
        
        return "\(averageAccuracy)%"
    }
    
    var guildRankDisplay: String {
        
        return "#\(guildRank)"
    }
    
    /// Human-readable reputation (1000 -> 1k)
    var newMembersDisplay: String {
        
        return "+\(newMembers)"
    }
    
    var activeUsersDisplay: String {
        
        return "\(activeUsers)"
    }
    
    var predictionsMadeDisplay: String {
        
        return "\(predictionsMade)"
    }
    
    /// Human-readable reputation (1000 -> 1k)
    var reputationEarnedDisplay: String {
        
        return "+\(reputationEarned)"
    }

    
}

// MARK: - Guild Membership DTO
/// Main User account for the guild
/// Represents a user's membership in a specific guild
/// Links a user to a guild with role, stats, and history
/// Used in: member lists, member profiles, membership management
struct GuildMembershipDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Membership record ID (not user ID!)
    let globalMember: GlobalMemberDTO      // EMBEDDED member data (no lookup!)
    let guild: GuildDTO      // EMBEDDED guild summary (just essentials)
    let roleInGuild: MemberRole       // Member's role in this specific guild
    let dateJoined: Date            // When user joined this guild
    let reputation: Int             // Reputation earned in this guild only
    let daysInGuild: Int            // Pre-calculated by backend for efficiency
    let contributionScore: Int      // Activity metric (0-100, higher = more active)
    let isOnline: Bool              // Real-time online status for presence indicator
    let isFriend: Bool              // Friend status for current user
    let isBlocked: Bool             // Blocked status for current user 
    
    /// Formatted membership duration
    var memberSince: String {
        if daysInGuild < 7 {
            return "Member for \(daysInGuild) days"
        } else if daysInGuild < 30 {
            return "Member for \(daysInGuild / 7) weeks"
        } else if daysInGuild < 365 {
            return "Member for \(daysInGuild / 30) months"
        } else {
            return "Member for \(daysInGuild / 365) years"
        }
    }
    
    /// Badge for new members
    var isNewMember: Bool {
        daysInGuild < 7
    }
    
    /// Badge for veteran members
    var isVeteran: Bool {
        daysInGuild > 365
    }
    
    /// Color for online status indicator
    var statusColor: Color {
        isOnline ? .green : .gray
    }
    
    /// Text for online status
    var statusText: String {
        isOnline ? "Online" : "Offline"
    }
}

// MARK: - Notification Type
enum NotificationType: String, Codable, CaseIterable {
    case personal = "Personal"
    case symbol = "Symbol"
    
}



enum NotificationDestination: Equatable {
    /// Navigate to a user's DM chat
    case userDM(userId: UUID)
    
    /// Navigate to a guild chatroom
    case chatroom(chatroomId: UUID)
    
    /// Navigate to a symbol's chart
    case symbolChart(symbolId: UUID, ticker: String)
    
    /// Navigate to a user's profile
    case userProfile(userId: UUID)
    
    /// Navigate to a guild announcement detail
    case announcement(announcementId: UUID)
    
    // Future destinations - uncomment as needed:
    // case trade(tradeId: UUID)
    // case challenge(challengeId: UUID)
    // case achievement(achievementId: UUID)
}





// MARK: - Guild Notification DTO
/// Main User account for the guild
/// Represents a user's membership in a specific guild
/// Links a user to a guild with role, stats, and history
/// Used in: member lists, member profiles, membership management
struct GuildNotificationDTO: Identifiable, Codable, Equatable {
    let id: UUID
    let member: GuildMembershipDTO
    let guild: GuildDTO
    let title: String
    let content: String
    let createdDate: Date
    let notificationType: NotificationType
    var isRead: Bool
    
    // ============================================================================
    // ✅ ADD THESE NAVIGATION FIELDS
    // ============================================================================
    /// User ID for DM-related notifications (e.g., "Sarah sent you a message")
    let targetUserId: UUID?
    
    /// Chatroom ID for chatroom-related notifications (e.g., "New message in #trading")
    let targetChatroomId: UUID?
    
    /// Symbol ID for symbol-related notifications (e.g., "EURUSD marker placed")
    let targetSymbolId: UUID?
    
    /// Symbol ticker for display purposes (e.g., "EURUSD", "BTC/USD")
    let targetSymbolTicker: String?
    
    /// Announcement ID for guild announcement notifications
    let targetAnnouncementId: UUID?
    
    /// Additional metadata as key-value pairs for future extensibility
    let targetMetadata: [String: String]?
    
    // ============================================================================
    // ✅ ADD THESE COMPUTED PROPERTIES
    // ============================================================================
    
    /// Computed navigation destination based on notification type and metadata
    var destination: NotificationDestination? {
        switch notificationType {
        case .personal:
            // Priority order for personal notifications:
            // 1. Chatroom message -> open chatroom
            if let chatroomId = targetChatroomId {
                return .chatroom(chatroomId: chatroomId)
            }
            
            // 2. DM message -> open DM with user
            if let userId = targetUserId {
                return .userDM(userId: userId)
            }
            
            // 3. Guild announcement -> open announcement detail
            if let announcementId = targetAnnouncementId {
                return .announcement(announcementId: announcementId)
            }
            
            // 4. Fallback to user profile
            return .userProfile(userId: member.id)
            
        case .symbol:
            // Symbol notifications always go to charts
            if let symbolId = targetSymbolId,
               let ticker = targetSymbolTicker {
                return .symbolChart(symbolId: symbolId, ticker: ticker)
            }
            
            // No valid symbol data
            return nil
        }
    }
    
    /// Check if notification has a valid destination (is tappable)
    var isActionable: Bool {
        destination != nil
    }
    
    // Existing computed property
    var timeAgoFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdDate, relativeTo: Date())
    }
}



// MARK: - Guild Announcement DTO
/// Important guild updates that persist (unlike chat messages)
/// Announcements are formal, authored communications
/// Used in: announcement board, guild homepage, notification center
struct GuildAnnouncementDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Announcement unique ID
    let guildId: UUID               // Guild ID
    let author: GuildMembershipDTO  // EMBEDDED author info
    let title: String               // Announcement headline
    let content: String             // Full announcement body (can be markdown)
    let preview: String             // Pre-truncated preview (~100 chars) from backend
    let postedAt: Date              // Timestamp when posted
    let timeAgoFormatted: String    // Pre-formatted by backend (e.g., "2 hours ago")
    let isImportant: Bool           // Should be highlighted/pinned at top
    var isRead: Bool                // Has current user read this? (personalized)
    let readCount: Int              // Total members who've read (for analytics)
    
    /// Color for importance indicator
    var importanceColor: Color {
        isImportant ? .red : .primary
    }
    
    /// Show unread dot indicator
    var showUnreadIndicator: Bool {
        !isRead
    }
    
    /// Read percentage for guild admins
    var readPercentage: Double {
        // This would need memberCount from guild
        // Just example calculation
        Double(readCount) / 100.0
    }
}

// MARK: - Guild Event DTO
/// EVENTUALLY ADD EVENT TYPES  - SUCH AS CHATROOM/SYMBOLS ETC
/// Scheduled activities, meetings, trading sessions, etc.
/// Events have a specific date/time unlike announcements
/// Used in: event calendar, RSVP management, reminders
struct GuildEventDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Event unique ID
    let guildId: UUID               // Parent guild ID for navigation
    let author: GuildMembershipDTO      // EMBEDDED creator info
    let title: String               // Event name
    let content: String             // Full description (can include links, rules, etc.)
    let preview: String             // Pre-truncated for list views
    let eventDate: Date             // When the event happens (future date)
    let eventDateFormatted: String  // Pre-formatted by backend (e.g., "Tomorrow at 3 PM EST")
    let timeUntilEvent: String      // Pre-formatted countdown (e.g., "in 2 days")
    let postedAt: Date              // When event was created
    let postedTimeAgo: String       // Pre-formatted creation time
    var attendeeCount: Int          // Number of members who RSVP'd yes
    var isAttending: Bool           // Current user's RSVP status (personalized)
    let attendees: [GuildMembershipDTO] // First 5-10 attendees for preview display
    let isImportant: Bool           // High-priority/mandatory event
    let canEdit: Bool               // Can current user edit? (based on backend permissions)
    var isRead: Bool             // Has user viewed the event
    
    /// Check if event has already happened
    var isPastEvent: Bool {
        eventDate < Date()
    }
    
    /// Color coding for event status
    var statusColor: Color {
        if isPastEvent {
            return .gray
        } else if isImportant {
            return .red
        } else if isAttending {
            return .green
        } else {
            return .blue
        }
    }
    
    /// User-friendly attendance display
    var attendanceDisplay: String {
        if isAttending {
            if attendeeCount == 1 {
                return "Just you"
            } else {
                return "You + \(attendeeCount - 1) others"
            }
        }
        return "\(attendeeCount) attending"
    }
}



// MARK: - Guild Watchlist DTO
/// Curated collection of symbols tracked by guild members
/// Can be personal or shared with guild
/// Used in: watchlist management, portfolio tracking
struct GuildWatchlistDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Watchlist unique ID
    let guildId: UUID               // Parent guild ID
    let name: String                // Watchlist name (e.g., "Tech Stocks")
    let author: GuildMembershipDTO      // EMBEDDED creator info
    let dateCreated: Date           // When watchlist was created
    let symbols: [SymbolDTO]        // EMBEDDED symbol data (not just IDs!)
    let symbolCount: Int            // Total symbols (may be > symbols.count if paginated)
    let lastUpdated: String         // Pre-formatted update time (e.g., "Updated 5 min ago")

    
    /// Check if watchlist is empty
    var isEmpty: Bool {
        symbols.isEmpty
    }
    
    
    /// Preview of symbols for list display
    var preview: String {
        let tickers = symbols.prefix(3).map { $0.ticker }.joined(separator: ", ")
        if symbols.count > 3 {
            return "\(tickers), +\(symbols.count - 3) more"
        }
        return tickers
    }

}



// MARK: - Friend DTO
/// Represents a friendship connection between guild members
/// Friends can see each other across guilds
/// Used in: friends list, friend activity, mutual guilds
struct GuildFriendDTO: Identifiable, Codable, Equatable {
    let id: UUID                          // Friendship record ID
    let guild: UUID                       // Guild ID
    let friend: GuildMembershipDTO        // EMBEDDED friend's full data
    let friendshipDate: Date              // When friendship started
    let friendshipDuration: String        // Pre-formatted (e.g., "Friends for 3 months")
    let mutualGuilds: [GuildSummaryDTO]   // EMBEDDED shared guilds
    let mutualGuildCount: Int             // Total mutual guilds (may be > array count)
    let lastSeen: String?                 // Pre-formatted activity (e.g., "Active 2 hours ago")
    
    /// Check if you share guilds
    var hasCommonGuilds: Bool {
        !mutualGuilds.isEmpty
    }
    
    /// Display text for mutual guilds
    var commonGuildsDisplay: String {
        switch mutualGuildCount {
        case 0: return "No mutual guilds"
        case 1: return "1 mutual guild"
        default: return "\(mutualGuildCount) mutual guilds"
        }
    }
    
    /// Check if friend is currently active
    var isRecentlyActive: Bool {
        lastSeen?.contains("min") ?? false || lastSeen?.contains("Active now") ?? false
    }
}





// ================================================================================================
// MARK: - Symbol / Charting DTOs
// ================================================================================================
// These handle all chat functionality: guild chatrooms and 1-on-1 direct messages
// No group messaging in current version per requirements
// ================================================================================================



// MARK: - Symbol Type
enum SymbolDTOType: String, Codable {
    case forex = "Forex"
    case commodities = "Commodities"
    case stocks = "Stocks"
    case cryptocurrency = "Cryptocurrency"
}

// MARK: - Symbol Status
enum SymbolDTOStatus: String, Codable {
    case open = "Open"
    case closed = "Closed"
}



// MARK: - Symbol DTO
/// Stock/cryptocurrency symbol information
/// Pre-formatted by backend with current prices
/// Used in: watchlists, trading views, market analysis
struct SymbolDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Symbol unique ID from database
    let ticker: String              // Trading symbol (e.g., "AAPL", "BTC")
    let name: String                // Full name (e.g., "Apple Inc.")
    let price: Decimal              // Current price as Decimal for precision
    let priceFormatted: String      // Pre-formatted with currency (e.g., "$182.52")
    let change: Decimal             // Day change amount
    let changeFormatted: String     // Pre-formatted percentage (e.g., "+2.34%")
    let changeColor: String         // "green" or "red" from backend
    let volume: Int                 // 24h trading volume
    let volumeFormatted: String     // Pre-formatted (e.g., "52.3M")
    let marketCap: String?          // Market cap if available (e.g., "2.9T")
    let symbolType: SymbolDTOType   // EMBEDDED Symbol Type - forex, commodity etc...
    let symbolStatus: SymbolDTOStatus   // EMBEDDED Symbol Status - Open/closed for the evening
    
    /// Convert backend color string to SwiftUI Color
    var changeColorSwiftUI: Color {
        changeColor == "green" ? .green : .red
    }
    
    /// Combined name for search/display
    var displayName: String {
        "\(ticker) • \(name)"
    }
    
    /// Check if price is up
    var isUp: Bool {
        changeColor == "green"
    }
    
    /// Arrow indicator for change
    var changeArrow: String {
        isUp ? "↑" : "↓"
    }
}



/// Represents an alert/message to display to the user
struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: AlertSeverity
    let style: AlertDisplayStyle
}

/// Severity level of the alert
enum AlertSeverity {
    case error
    case warning
    case info
    case success
    
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .success: return AppColors.bullCandleGreen
        }
    }
    
    var icon: String {
        switch self {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}

/// How the alert should be displayed
enum AlertDisplayStyle {
    case alert      // Modal alert (blocking)
    case toast      // Toast notification (non-blocking)
}





