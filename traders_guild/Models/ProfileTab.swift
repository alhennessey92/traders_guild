//
//  ProfileTab.swift
//  traders_guild
//
//  Shared profile tabs used by ProfileContentView.
//

import Foundation

/// Tab enum for profile sections - used by both current user and member profiles
enum ProfileTab: String, CaseIterable, UnifiedTabItem {
    case overview = "Overview"
    case markers = "Markers"
    case awards = "Awards"
    case activity = "Activity"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "person.text.rectangle"
        case .markers: return "mappin.and.ellipse"
        case .awards: return "trophy.fill"
        case .activity: return "clock.fill"
        }
    }
}
