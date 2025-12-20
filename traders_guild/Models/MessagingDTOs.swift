//
//  MessagingDTOs.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/12/2025.
//

import Foundation
import SwiftUI



// ================================================================================================
// MARK: - MESSAGING DTOs
// ================================================================================================
// These handle all chat functionality: guild chatrooms and 1-on-1 direct messages
// No group messaging in current version per requirements
// ================================================================================================


// MARK: - Guild Chatroom DTO
/// Represents a chat channel within a guild
/// Guilds can have multiple chatrooms for different topics
/// Used in: channel list, channel selector, chat view
struct GuildChatroomDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Chatroom unique ID
    let guildId: UUID               // Parent guild ID
    let name: String                // Channel name (e.g., "general", "trading-signals")
    let description: String?        // Channel topic/description
    let lastMessage: ChatroomMessageDTO?    // Most recent message for preview
    let isActive: Bool              // True / false
    let lastActivity: Date          // Timestamp of last message
    let lastActivityFormatted: String // Pre-formatted (e.g., "Active 2 min ago")
    var unreadCount: Int            // Unread messages for current user (personalized)
    let memberCount: Int            // Members with access to this channel
    let isPinned: Bool              // Pinned to top for current user (personalized)
    let isMuted: Bool               // Muted notifications for current user (personalized)
    let canSendMessages: Bool       // Can current user post? (based on permissions)
    
    /// Check if has unread messages
    var hasUnread: Bool {
        unreadCount > 0
    }
    

    
    /// Badge color based on activity
    var activityColor: Color {
        if hasUnread {
            return .blue
        } else if isPinned {
            return .yellow
        }
        return .clear
    }
}


// MARK: - ChatroomMessage DTO
/// Contains all display data including reactions and attachments
/// Used in: chat views, message history, search results
struct ChatroomMessageDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Message unique ID
    let chatroom: UUID              // Guild Chatroom ID
    let author: GuildMembershipDTO      // EMBEDDED sender info
    let content: String             // Message text content (can include markdown)
    let timestamp: Date             // When message was sent
    let timestampFormatted: String  // Pre-formatted time (e.g., "2:34 PM" or "Yesterday")
    let isEdited: Bool              // Has message been edited after sending
    let isCurrentUserMessage: Bool  // Did current user send this? (for UI styling)
    let canEdit: Bool               // Can current user edit? (based on permissions)
    let canDelete: Bool             // Can current user delete? (based on permissions)
    
    
    /// Message alignment in chat UI
    var alignment: HorizontalAlignment {
        isCurrentUserMessage ? .trailing : .leading
    }
}



// MARK: - Direct Message DTO
/// Represents a 1-on-1 conversation with another user
/// Direct messages exist outside of guild context
/// Used in: DM list, DM conversation view
struct DMDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Conversation unique ID
    let guildId: Int                // Guild Id
    let participant: GuildMembershipDTO // EMBEDDED other person's data
    let lastMessage: DMMessageDTO?    // Most recent message in conversation
    let lastActivity: Date          // Timestamp of last message
    let lastActivityFormatted: String // Pre-formatted time
    var unreadCount: Int            // Number of unread messages (personalized)
    let isBlocked: Bool             // Has user blocked this person?

    
    /// Check if has unread messages
    var hasUnread: Bool {
        unreadCount > 0
    }
    
    /// Status indicator color
    var statusColor: Color {
        participant.isOnline ? .green : .gray
    }
    
    /// Display name for conversation
    var displayName: String {
        participant.globalMember.name
    }
    
    /// Preview text for conversation list
    var preview: String {
        lastMessage?.content ?? "Start a conversation"
    }
    
    /// Should show notification badge
    var shouldShowBadge: Bool {
        hasUnread && !isBlocked
    }
}



// MARK: - Direct Message DTO
/// Contains all display data including reactions and attachments
/// Used in: chat views, message history, search results
struct DMMessageDTO: Identifiable, Codable, Equatable {
    let id: UUID                    // Message unique ID
    let dmId: UUID              // Direct Message ID
    let author: GuildMembershipDTO      // EMBEDDED sender info
    let content: String             // Message text content (can include markdown)
    let timestamp: Date             // When message was sent
    let timestampFormatted: String  // Pre-formatted time (e.g., "2:34 PM" or "Yesterday")
    let isEdited: Bool              // Has message been edited after sending
    let isCurrentUserMessage: Bool  // Did current user send this? (for UI styling)
    let canEdit: Bool               // Can current user edit? (based on permissions)
    let canDelete: Bool             // Can current user delete? (based on permissions)
    let isRead: Bool                // Has current user seen this?
    
    
    /// Message alignment in chat UI
    var alignment: HorizontalAlignment {
        isCurrentUserMessage ? .trailing : .leading
    }
}



// MARK: - Chart Chat DTO
/// Represents a chat channel specific to a symbol and guild combination
/// Used for real-time collaboration on chart analysis
struct ChartChatDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Chat unique ID
    let symbolId: UUID                  // Symbol being discussed
    let symbolTicker: String            // Symbol ticker (e.g., "BTC/USD")
    let guildId: UUID                   // Guild context
    let guildName: String               // Guild name for display
    let lastMessage: ChartChatMessageDTO?   // Most recent message
    let lastActivity: Date              // Timestamp of last message
    let lastActivityFormatted: String   // Pre-formatted time
    var unreadCount: Int                // Unread messages (personalized)
    let activeUsers: [GuildMembershipDTO]   // Currently active users in chat
    let activeUserCount: Int            // Total active users
    let canSendMessages: Bool           // Can current user post?
    
    /// Check if has unread messages
    var hasUnread: Bool {
        unreadCount > 0
    }
    
    /// Display name for the chat
    var displayName: String {
        "\(symbolTicker) • \(guildName)"
    }
    
    /// Preview text for conversation list
    var preview: String {
        lastMessage?.content ?? "Start analyzing \(symbolTicker)"
    }
    
    /// Active users preview text
    var activeUsersDisplay: String {
        switch activeUserCount {
        case 0: return "No one active"
        case 1: return "1 person analyzing"
        default: return "\(activeUserCount) people analyzing"
        }
    }
}

// MARK: - Chart Chat Message DTO
/// Individual message in a chart chat
/// Contains all display data including author and permissions
struct ChartChatMessageDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Message unique ID
    let chartChatId: UUID               // Parent chat ID
    let author: GuildMembershipDTO      // EMBEDDED sender info
    let content: String                 // Message text content
    let timestamp: Date                 // When message was sent
    let timestampFormatted: String      // Pre-formatted time
    let isEdited: Bool                  // Has message been edited
    let isCurrentUserMessage: Bool      // Did current user send this?
    let canEdit: Bool                   // Can current user edit?
    let canDelete: Bool                 // Can current user delete?
    
    /// Message alignment in chat UI
    var alignment: HorizontalAlignment {
        isCurrentUserMessage ? .trailing : .leading
    }
}



// MARK: - Chart Marker Chat Message DTO
/// Individual message in a chart marker chat
/// Contains all display data including author and permissions
struct MarkerCommentDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Comment unique ID
    let markerId: UUID                  // Parent marker ID
    let author: GuildMembershipDTO      // EMBEDDED author info (consistent with other DTOs)
    let content: String                 // Comment text
    let timestamp: Date                 // When comment was posted
    let timestampFormatted: String      // Pre-formatted time from backend
    let isEdited: Bool                  // Has comment been edited
    let isCurrentUserMessage: Bool      // Did current user post this?
    let canEdit: Bool                   // Can current user edit?
    let canDelete: Bool                 // Can current user delete?
    
    /// Message alignment in UI
    var alignment: HorizontalAlignment {
        isCurrentUserMessage ? .trailing : .leading
    }
}


// MARK: - MarkerCommentDTO Extensions

extension MarkerCommentDTO {
    
    /// Author's display name for UI
    var authorDisplayName: String {
        author.globalMember.username
    }
    
    /// Author's initials for avatar
    var authorInitials: String {
        String(author.globalMember.username.prefix(2)).uppercased()
    }
    
    /// Author's avatar URL
    var authorAvatarURL: String? {
        author.globalMember.avatarURL
    }
    
    /// Is author currently online
    var authorIsOnline: Bool {
        author.isOnline
    }
    
    /// Author's role in guild
    var authorRole: MemberRole {
        author.roleInGuild
    }
    
    /// Author's reputation
    var authorReputation: Int {
        author.reputation
    }
}

// MARK: - ChatMessageDisplayable Conformance

extension MarkerCommentDTO: ChatMessageDisplayable {
    // authorDisplayName, authorInitials already provided above
    // These are required by ChatMessageDisplayable protocol:
    
    var authorIsFriend: Bool {
        author.isFriend
    }
    
    var authorIsBlocked: Bool {
        author.isBlocked
    }
}

// MARK: - Date Formatting Extensions

extension Date {
    /// Returns a relative timestamp string (e.g., "2 min ago")
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns a chat-style timestamp
    /// - Today: "2:34 PM"
    /// - This week: "Mon 2:34 PM"
    /// - Older: "Dec 15, 2:34 PM"
    var chatTimestamp: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday \(formatter.string(from: self))"
        } else if let daysAgo = calendar.dateComponents([.day], from: self, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE h:mm a"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: self)
        }
    }
    
    /// Short relative timestamp (e.g., "2m", "3h", "5d")
    var shortRelativeTimestamp: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks)w"
        } else if let days = components.day, days > 0 {
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
    
//    /// Format for chart time labels
//    var chartTimeLabel: String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm"
//        return formatter.string(from: self)
//    }
}


























// MARK: - Reaction DTO
/// Emoji reaction on a message
/// Tracks who reacted and if current user reacted
//struct ReactionDTO: Codable, Equatable {
//    let emoji: String               // The emoji character (e.g., "👍", "😄")
//    let count: Int                  // Total number of users who used this reaction
//    let userReacted: Bool           // Did current user add this reaction? (personalized)
//
//    /// Display text for reaction button
//    var displayText: String {
//        count > 1 ? "\(emoji) \(count)" : emoji
//    }
//}

// MARK: - Message Reference DTO
/// Reference to another message (for reply chains)
/// Contains just enough info to show reply context
//struct MessageReferenceDTO: Codable, Equatable {
//    let id: UUID                    // Original message ID
//    let authorName: String          // Original author's name
//    let contentPreview: String      // First ~50 characters of original message
//
//    /// Formatted reply preview
//    var replyPreview: String {
//        "↩️ \(authorName): \(contentPreview)"
//    }
//}

// MARK: - Attachment DTO
/// File/media attached to a message
/// Supports images, files, documents
//struct AttachmentDTO: Identifiable, Codable, Equatable {
//    let id: UUID                    // Attachment unique ID
//    let type: String                // Type: "image", "file", "video", "document"
//    let url: String                 // Download/view URL from CDN
//    let thumbnailURL: String?       // Thumbnail URL for preview (images/videos)
//    let fileName: String            // Original filename
//    let fileSize: String            // Pre-formatted size (e.g., "2.3 MB")
//
//    /// Icon for file type
//    var fileIcon: String {
//        switch type {
//        case "image": return "photo"
//        case "video": return "video"
//        case "document": return "doc.text"
//        default: return "paperclip"
//        }
//    }
//
//    /// Check if attachment can be previewed inline
//    var canPreview: Bool {
//        type == "image" || type == "video"
//    }
//}
