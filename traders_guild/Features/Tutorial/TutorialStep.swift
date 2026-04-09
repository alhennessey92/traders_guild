import SwiftUI

// MARK: - Tutorial Step

/// Defines every step in the in-app guided tour.
/// Each case carries metadata used by `TutorialManager` and `TutorialOverlayView`
/// to position spotlights, open the correct drawer, and display the right copy.
enum TutorialStep: Int, CaseIterable, Codable {
    case welcome
    case guildInfo
    case guildMenu
    case announcements
    case events
    case leaderboard
    case chat
    case chart
    case markersIntro
    case setupMarkers
    case indicatorsDrawings
    case timeframeLinking
    case chartSetupCopying
    case linkingMarkersChat
    case watchlists
    case complete

    // MARK: - Total

    static var totalSteps: Int { allCases.count }

    /// 1-based step number for display.
    var stepNumber: Int { rawValue + 1 }

    // MARK: - Full-Width Spotlight

    /// Extra padding added above the spotlight rect for steps that need a taller cutout.
    var spotlightExtraTopPadding: CGFloat {
        switch self {
        case .chart:
            return 60
        case .timeframeLinking:
            // Lift cutout so chart timeframe price header stays fully in the lit region (not under dimming).
            return 220
        case .markersIntro, .setupMarkers, .indicatorsDrawings, .chartSetupCopying, .linkingMarkersChat:
            return 160
        default:
            return 0
        }
    }

    /// When true, the spotlight cutout stretches to the full screen width
    /// and extends down to the bottom edge of the screen.
    var fullWidthSpotlight: Bool {
        switch self {
        case .chart, .markersIntro, .setupMarkers, .indicatorsDrawings,
             .timeframeLinking, .chartSetupCopying, .linkingMarkersChat:
            return true
        default:
            return false
        }
    }

    // MARK: - Required Sheet Tab

    /// For non-spotlight steps, which bottom sheet tab to show (expanding the sheet).
    /// Returns nil if the step doesn't require a specific tab.
    var requiredSheetTab: String? {
        switch self {
        case .markersIntro, .setupMarkers:
            return "Markers"
        case .indicatorsDrawings, .chartSetupCopying:
            return "Components"
        case .linkingMarkersChat:
            return "Chat"
        case .timeframeLinking:
            return "Components"
        default:
            return nil
        }
    }

    // MARK: - Required Drawer State

    enum RequiredDrawer {
        case center
        case leftOpen
        case rightOpen
    }

    var requiredDrawer: RequiredDrawer {
        switch self {
        case .guildInfo, .guildMenu, .announcements, .events, .leaderboard, .watchlists:
            return .leftOpen
        case .chat:
            return .rightOpen
        default:
            return .center
        }
    }

    // MARK: - Spotlight Key

    /// Non-nil when the step should cut a spotlight hole around a registered anchor.
    var spotlightKey: String? {
        switch self {
        case .guildInfo:            return "guild-header"
        case .guildMenu:            return "guild-menu-area"
        case .announcements:        return "menu-Announcements"
        case .events:               return "menu-Events"
        case .leaderboard:          return "menu-Leaderboard"
        case .chat:                 return "chat-header"
        case .chart:                return "bottom-bar"
        case .markersIntro:         return "bottom-sheet"
        case .setupMarkers:         return "bottom-sheet"
        case .indicatorsDrawings:   return "bottom-sheet"
        case .timeframeLinking:     return "bottom-sheet"
        case .chartSetupCopying:    return "bottom-sheet"
        case .linkingMarkersChat:   return "bottom-sheet"
        case .watchlists:           return "menu-Watchlists"
        default:                    return nil
        }
    }

    // MARK: - Tooltip Position

    enum TooltipPosition {
        case above
        case below
        case center
    }

    var tooltipPosition: TooltipPosition {
        switch self {
        case .guildInfo:
            return .below
        case .guildMenu, .announcements, .events, .leaderboard, .watchlists:
            return .below
        case .chat:
            return .below
        case .chart, .markersIntro, .setupMarkers, .indicatorsDrawings,
             .timeframeLinking, .chartSetupCopying, .linkingMarkersChat:
            return .above
        default:
            return .center
        }
    }

    // MARK: - Icon

    var icon: String {
        switch self {
        case .welcome:              return "hand.wave.fill"
        case .guildInfo:            return "shield.pattern.checkered"
        case .guildMenu:            return "list.bullet.rectangle.fill"
        case .announcements:        return "megaphone.fill"
        case .events:               return "calendar.badge.clock"
        case .leaderboard:          return "trophy.fill"
        case .chat:                 return "bubble.left.and.bubble.right.fill"
        case .chart:                return "chart.xyaxis.line"
        case .markersIntro:         return "star.bubble.fill"
        case .setupMarkers:         return "target"
        case .indicatorsDrawings:   return "waveform.path.ecg"
        case .timeframeLinking:     return "link"
        case .chartSetupCopying:    return "doc.on.doc.fill"
        case .linkingMarkersChat:   return "arrowshape.turn.up.right.fill"
        case .watchlists:           return "star.fill"
        case .complete:             return "checkmark.seal.fill"
        }
    }

    // MARK: - Accent Color

    var accentColor: Color {
        switch self {
        case .welcome:              return AppColors.accentColor
        case .guildInfo:            return AppColors.accentColor
        case .guildMenu:            return AppColors.signupInterestBlue
        case .announcements:        return .orange
        case .events:               return AppColors.signupInterestGreen
        case .leaderboard:          return .yellow
        case .chat:                 return AppColors.signupInterestBlue
        case .chart:                return AppColors.accentColor
        case .markersIntro:         return AppColors.signupInterestBlue
        case .setupMarkers:         return AppColors.signupInterestGreen
        case .indicatorsDrawings:   return .purple
        case .timeframeLinking:     return .cyan
        case .chartSetupCopying:    return .orange
        case .linkingMarkersChat:   return AppColors.signupInterestBlue
        case .watchlists:           return .yellow
        case .complete:             return AppColors.signupInterestGreen
        }
    }

    // MARK: - Title & Message

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Your Guild"
        case .guildInfo:
            return "Guild Overview"
        case .guildMenu:
            return "Guild Navigation"
        case .announcements:
            return "Announcements"
        case .events:
            return "Events"
        case .leaderboard:
            return "Leaderboard"
        case .chat:
            return "Chat & Messaging"
        case .chart:
            return "Chart Controls"
        case .markersIntro:
            return "Markers"
        case .setupMarkers:
            return "Setup Markers & Tracking"
        case .indicatorsDrawings:
            return "Indicators & Drawings"
        case .timeframeLinking:
            return "Timeframe Linking"
        case .chartSetupCopying:
            return "Copy Chart Setup"
        case .linkingMarkersChat:
            return "Share Markers in Chat"
        case .watchlists:
            return "Watchlists"
        case .complete:
            return "You're All Set!"
        }
    }

    var message: String {
        switch self {
        case .welcome:
            return "Let's take a quick tour of your guild. You'll learn how everything works in just a couple of minutes. You can skip anytime and come back later from Settings."
        case .guildInfo:
            return "This is your guild's home. Here you can see the guild name, member count, online status, total guild reputation, and overall accuracy rate."
        case .guildMenu:
            return "Use this menu to navigate between guild sections \u{2014} announcements, events, markers, leaderboard, watchlists, member list, and statistics are all here."
        case .announcements:
            return "Guild admins post important updates here. You'll see a notification dot when there's something new to read."
        case .events:
            return "Upcoming guild events and competitions appear here. Join events to participate with your guildmates and build reputation."
        case .leaderboard:
            return "See who's leading the guild in accuracy and reputation. Tracked setup markers contribute to your ranking here."
        case .chat:
            return "This is your messaging hub. Access guild chatrooms for group discussions, and direct messages for private conversations with guildmates."
        case .chart:
            return "This is your control bar. Switch symbols, open chart chat, add indicators and drawings to the chart, or tap the marker button to start placing a marker."
        case .markersIntro:
            return "Markers are annotations you place directly on the chart. Choose from 8 types \u{2014} setups, analysis, alerts, questions, polls, news, reactions, and personal notes \u{2014} so your ideas stay attached to market context."
        case .setupMarkers:
            return "Setup markers track real trades with entry, stop-loss, and take-profit levels. The system automatically monitors price action and records whether your setup hits TP or SL, building your accuracy rating and reputation over time."
        case .indicatorsDrawings:
            return "Attach technical indicators (RSI, MACD, Stochastic, and more) and drawings (trendlines, zones, horizontal levels) to your markers so others can see your full analysis in context."
        case .timeframeLinking:
            return "Link your markers to multiple timeframes for multi-timeframe analysis. When someone views your marker, they'll see synchronized charts across the timeframes you selected."
        case .chartSetupCopying:
            return "Use \"Attach Current Chart Setup\" to instantly copy your active indicators and drawings onto a marker. This mirrors your exact chart configuration so viewers see exactly what you see."
        case .linkingMarkersChat:
            return "Share markers directly in guild chatrooms. Members can tap a shared marker to jump straight to it on the chart, keeping discussions connected to the analysis."
        case .watchlists:
            return "Manage your personal watchlist, browse the guild watchlist curated by admins, or explore the global symbol list. Watchlists give you quick access to the symbols you care about."
        case .complete:
            return "You're ready to start exploring! You can revisit this tutorial anytime from Settings. Happy trading with your guild!"
        }
    }
}
