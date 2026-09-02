//
//  MarkerDiscordOptIn.swift
//  traders_guild
//
//  Letting an author mirror a marker into their guild's Discord as they place
//  it, rather than remembering to share it afterwards.
//
//  This is the entry half of the loop the guild's Discord sees: the idea goes
//  out when it is placed, and the server posts the outcome back into the same
//  channel when the setup resolves. It is deliberately a per-marker choice —
//  the guild-wide auto-post switch broadcasts markers nobody consciously
//  shared, which is why that one is restricted to closed guilds and this one
//  is not.
//

import SwiftUI

/// Remembers which channel the author last posted to, per guild.
///
/// A preference, not a setting: it pre-selects the destination so the common
/// case is one tap, but the toggle still starts off, so nothing is ever posted
/// because of a choice made last week.
enum MarkerDiscordPreference {
    private static let channelKeyPrefix = "marker.discord.lastChannel."

    static func lastChannelId(guildId: UUID) -> UUID? {
        let raw = UserDefaults.standard.string(forKey: channelKeyPrefix + guildId.uuidString)
        return raw.flatMap(UUID.init(uuidString:))
    }

    static func remember(channelId: UUID, guildId: UUID) {
        UserDefaults.standard.set(
            channelId.uuidString, forKey: channelKeyPrefix + guildId.uuidString
        )
    }
}

/// The composer's "post this to Discord" row.
///
/// Hidden entirely when the guild has no usable channel: an author who cannot
/// act on it should not be shown a control that explains why not.
struct MarkerDiscordOptInSection: View {
    @ObservedObject var placementState: MarkerPlacementState
    let guildId: UUID?

    private var usableChannels: [RLGuildDiscordChannelDTO] {
        placementState.discordChannels.filter(\.canPost)
    }

    private var isOn: Bool { placementState.selectedDiscordChannelId != nil }

    private var selectedChannel: RLGuildDiscordChannelDTO? {
        usableChannels.first { $0.id == placementState.discordChannelId }
    }

    var body: some View {
        if !usableChannels.isEmpty && placementState.visibility == "guild" {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: toggleBinding) {
                    HStack(spacing: 8) {
                        Image("DiscordLogo")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(
                                isOn ? AppColors.guildReputationAccent : AppColors.greyText
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Post to Discord")
                                .foregroundColor(AppColors.primaryForeground)
                                .font(.subheadline)
                            Text(subtitle)
                                .foregroundColor(AppColors.greyText)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .tint(AppColors.guildReputationAccent)

                // Only worth a picker when there is a choice to make.
                if isOn && usableChannels.count > 1 {
                    channelPicker
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var subtitle: String {
        guard isOn else {
            return "Share this marker in your guild's Discord as you place it."
        }
        if placementState.trackingEnabled {
            // The reason to say yes, stated at the moment of saying it.
            return "The result is posted there too when this setup resolves."
        }
        return "Posted to \(selectedChannel?.displayLabel ?? "your Discord") now."
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { enabled in
                guard enabled else {
                    placementState.discordChannelId = nil
                    return
                }
                placementState.discordChannelId = defaultChannelId()
                if let guildId, let chosen = placementState.discordChannelId {
                    MarkerDiscordPreference.remember(channelId: chosen, guildId: guildId)
                }
                HapticFeedback.light.trigger()
            }
        )
    }

    /// Last used for this guild, else the guild's default, else the first one.
    private func defaultChannelId() -> UUID? {
        if let guildId,
           let remembered = MarkerDiscordPreference.lastChannelId(guildId: guildId),
           usableChannels.contains(where: { $0.id == remembered }) {
            return remembered
        }
        return (usableChannels.first(where: \.isDefault) ?? usableChannels.first)?.id
    }

    private var channelPicker: some View {
        Menu {
            ForEach(usableChannels) { channel in
                Button {
                    placementState.discordChannelId = channel.id
                    if let guildId {
                        MarkerDiscordPreference.remember(channelId: channel.id, guildId: guildId)
                    }
                } label: {
                    if channel.id == placementState.discordChannelId {
                        Label(channel.displayLabel, systemImage: "checkmark")
                    } else {
                        Text(channel.displayLabel)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedChannel?.displayLabel ?? "Choose a channel")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.greyText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.surfaceWhite08)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
        }
    }
}
