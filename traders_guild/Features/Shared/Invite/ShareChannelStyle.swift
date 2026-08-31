//
//  ShareChannelStyle.swift
//  traders_guild
//
//  One definition of how each share destination looks, shared by the two
//  surfaces that offer them: GuildInviteHubView and MarkerSharePromptSheet.
//
//  These two had drifted. The invite hub drew brand marks in their own colours
//  and gave each utility channel its own tint; the marker sheet flattened every
//  mark to white and every symbol to a single accent, and drew X as the "𝕏"
//  character rather than the asset. Same destinations, two looks. The hub's
//  treatment is the one that reads as branded, so it is the one that survives —
//  and it now lives here so a third surface can't invent a fourth style.
//

import SwiftUI

/// How a channel's mark is drawn.
///
/// Brand marks are assets and always render `.original`: Discord is blurple,
/// Telegram is its blue, Reddit is orange. Utility channels are SF Symbols and
/// take the spec's `tint`.
enum ShareChannelIcon {
    case system(String)
    case asset(String)
}

struct ShareChannelSpec {
    let icon: ShareChannelIcon
    /// Applied to SF Symbols only — an asset carries its own colour.
    let tint: Color
}

/// Every destination either share surface can offer, and the order both must show them in.
///
/// The order is the contract, not a suggestion. Someone who has shared a guild invite should
/// find X in the same place when they share a marker — and until now they didn't: the two
/// surfaces each declared their own private `ChannelKind` and their own literal ordering, so
/// X and Discord were swapped on one and Telegram and Reddit on the other.
///
/// `ShareChannelStyle` already existed to stop these two drifting, but it only owned how a
/// channel *looks*. Order is the other half, so it lives here too, and each surface renders
/// `canonicalOrder` filtered to what it actually offers — a new channel then lands in the
/// same slot everywhere by construction.
enum ShareChannel: CaseIterable {
    /// The public channels. These four are the top row of every share surface.
    case x, discord, reddit, telegram
    /// Send it to one person, inside the app. Only one of these appears per surface.
    case guildDM, messages
    /// Utilities, always last.
    case copyLink, qrCode, more

    /// The single source of order. Every surface's list must be a subsequence of this.
    ///
    /// Both surfaces lay out four to a row, so the first four entries *are* the top row:
    /// X, Discord, Reddit, Telegram, in that order, on every share screen in the app.
    /// Everything else sits underneath.
    static let canonicalOrder: [ShareChannel] = [
        .x, .discord, .reddit, .telegram,
        .guildDM, .messages,
        .copyLink, .qrCode, .more,
    ]

    var spec: ShareChannelSpec {
        switch self {
        case .guildDM:  return ShareChannelStyle.guildDM
        case .messages: return ShareChannelStyle.messages
        case .x:        return ShareChannelStyle.x
        case .discord:  return ShareChannelStyle.discord
        case .telegram: return ShareChannelStyle.telegram
        case .reddit:   return ShareChannelStyle.reddit
        case .copyLink: return ShareChannelStyle.copyLink
        case .qrCode:   return ShareChannelStyle.qrCode
        case .more:     return ShareChannelStyle.more
        }
    }

    /// The label both surfaces use, unless one has a reason to override it (the marker
    /// sheet names a connected Discord channel).
    var title: String {
        switch self {
        case .guildDM:  return "Guild DM"
        case .messages: return "Messages"
        case .x:        return "X"
        case .discord:  return "Discord"
        case .telegram: return "Telegram"
        case .reddit:   return "Reddit"
        case .copyLink: return "Copy link"
        case .qrCode:   return "QR code"
        case .more:     return "More"
        }
    }
}

/// The channel table.
///
/// Computed rather than stored: every `AppColors` token here is theme-aware, and
/// a `static let` would freeze whichever theme happened to be active the first
/// time the sheet was built.
enum ShareChannelStyle {

    // Brand marks. `tint` is unused for these but kept non-optional so a caller
    // can't accidentally get an untinted symbol.
    static var x: ShareChannelSpec { .init(icon: .asset("XLogo"), tint: AppColors.whiteText) }
    static var discord: ShareChannelSpec { .init(icon: .asset("DiscordLogo"), tint: AppColors.whiteText) }
    static var reddit: ShareChannelSpec { .init(icon: .asset("RedditLogo"), tint: AppColors.whiteText) }
    static var telegram: ShareChannelSpec { .init(icon: .asset("TelegramLogo"), tint: AppColors.whiteText) }

    // Utility channels.
    static var guildDM: ShareChannelSpec { .init(icon: .system("person.2.fill"), tint: AppColors.accentColor) }
    static var messages: ShareChannelSpec { .init(icon: .system("message.fill"), tint: AppColors.statusPositive70) }
    static var copyLink: ShareChannelSpec { .init(icon: .system("doc.on.doc.fill"), tint: AppColors.guildReputationAccent) }
    static var qrCode: ShareChannelSpec { .init(icon: .system("qrcode"), tint: AppColors.whiteText) }
    static var more: ShareChannelSpec { .init(icon: .system("square.and.arrow.up"), tint: AppColors.friendAccent) }
}

// MARK: - Rendering

/// The mark itself. Both surfaces wrap this in their own container — a circle
/// in the marker sheet, a rounded tile in the invite hub — because they sit in
/// different layouts; only the mark is shared.
///
/// `size` sizes the brand assets, which the two surfaces already drew at
/// slightly different scales (26pt in the sheet, 24pt in the hub). SF Symbols
/// were 22pt in both, so that stays fixed and nothing shifts on screen.
struct ShareChannelMark: View {
    let spec: ShareChannelSpec
    var size: CGFloat = 26

    var body: some View {
        switch spec.icon {
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(spec.tint)
        }
    }
}
