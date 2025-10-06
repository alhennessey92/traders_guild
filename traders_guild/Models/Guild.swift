//
//  Guild.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import Foundation
import SwiftUI

// MARK: - Announcement Models
struct GuildAnnouncement: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let content: String
    let author: String
    let authorRole: UserRole
    let postedAt: Date
    let isImportant: Bool
    let readBy: Set<UUID> = []
    
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
