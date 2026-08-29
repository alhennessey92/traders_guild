//
//  DiscordShareDestinationViews.swift
//  traders_guild
//
//  Shared destination picker and previews for direct Discord webhook shares.
//  Webhook URLs never enter these views; only server-masked channel DTOs do.
//

import SwiftUI

struct DiscordDestinationSheet<Preview: View>: View {
    let title: String
    let channels: [RLGuildDiscordChannelDTO]
    @Binding var selectedChannelId: UUID?
    let isPosting: Bool
    @ViewBuilder let preview: () -> Preview
    let onPost: () -> Void
    let onCopyAndOpen: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var usableChannels: [RLGuildDiscordChannelDTO] {
        channels.filter(\.canPost)
    }

    private var selectedChannel: RLGuildDiscordChannelDTO? {
        usableChannels.first { $0.id == selectedChannelId }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.greyText)
                        preview()
                    }

                    if usableChannels.isEmpty {
                        // No webhook on this guild — the system guild, or one
                        // nobody has connected yet. Say so plainly: this used to
                        // copy and jump to Discord with no explanation, leaving
                        // people on Discord's home screen wondering what happened.
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No connected channel")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.greyText)
                            Text("This guild hasn't connected a Discord channel, so we can't post for you. Copy the message and paste it into any channel yourself.")
                                .font(.footnote)
                                .foregroundColor(AppColors.greyText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Destination")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.greyText)
                            channelPicker
                        }

                        Button(action: onPost) {
                            Group {
                                if isPosting {
                                    ProgressView().tint(AppColors.onAccentForeground)
                                } else {
                                    Text(selectedChannel.map { "Post to \($0.displayLabel)" } ?? "Choose a channel")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(AppColors.onAccentForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedChannel == nil ? AppColors.surfaceWhite12 : AppColors.tgAccent)
                            )
                        }
                        .buttonStyle(InvitePressStyle())
                        .disabled(selectedChannel == nil || isPosting)
                    }

                    Button {
                        onCopyAndOpen()
                    } label: {
                        Text("Copy message and open Discord")
                            .font(usableChannels.isEmpty ? .headline : .subheadline.weight(.semibold))
                            .foregroundColor(
                                usableChannels.isEmpty
                                    ? AppColors.onAccentForeground
                                    : AppColors.guildReputationAccent
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, usableChannels.isEmpty ? 14 : 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(usableChannels.isEmpty ? AppColors.tgAccent : Color.clear)
                            )
                    }
                    .buttonStyle(InvitePressStyle())
                    .disabled(isPosting)
                }
                .padding(20)
            }
            .background(AppColors.sheetBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accentColor)
                }
            }
            .onAppear(perform: ensureSelection)
            .onChange(of: channels) { _, _ in ensureSelection() }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var channelPicker: some View {
        if usableChannels.count == 1, let channel = usableChannels.first {
            channelLabel(channel)
        } else {
            Menu {
                ForEach(usableChannels) { channel in
                    Button {
                        selectedChannelId = channel.id
                    } label: {
                        if channel.id == selectedChannelId {
                            Label(channel.displayLabel, systemImage: "checkmark")
                        } else {
                            Text(channel.displayLabel)
                        }
                    }
                }
            } label: {
                if let selectedChannel {
                    channelLabel(selectedChannel)
                } else {
                    HStack {
                        Text("Choose a Discord channel")
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.greyText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(pickerBackground)
                }
            }
        }
    }

    private func channelLabel(_ channel: RLGuildDiscordChannelDTO) -> some View {
        HStack(spacing: 10) {
            Image("DiscordLogo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(AppColors.whiteText)
            Text(channel.displayLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.whiteText)
            if channel.isDefault {
                Text("Default")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.guildReputationAccent)
            }
            Spacer()
            if usableChannels.count > 1 {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(pickerBackground)
    }

    private var pickerBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.surfaceWhite08)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.surfaceWhite12, lineWidth: 1)
            )
    }

    private func ensureSelection() {
        if let selectedChannelId,
           usableChannels.contains(where: { $0.id == selectedChannelId }) {
            return
        }
        selectedChannelId = RLGuildDiscordChannelsListDTO(channels: usableChannels).preferredChannel?.id
    }
}

struct DiscordMarkerEmbedPreview: View {
    let symbolTicker: String?
    let timeframe: String
    let timestamp: Date
    let intent: RLMarkerIntent
    let alertSeverity: MarkerAlertSeverity?
    let emoji: String?
    let caption: String?

    private var ticker: String {
        let trimmed = symbolTicker?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "MARKET" : trimmed
    }

    private var trimmedCaption: String? {
        let value = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var body: some View {
        DiscordEmbedFrame {
            LinkedMarkerRow(
                intent: intent,
                alertSeverity: alertSeverity,
                emoji: emoji,
                ticker: ticker,
                assetClass: nil,
                brandColorHex: nil,
                timeframe: timeframe,
                subtitle: timestamp.formatted(date: .abbreviated, time: .shortened),
                style: .messageCard(isCurrentUserMessage: false)
            )
            if let trimmedCaption {
                Text(trimmedCaption)
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("The chart image and marker levels will be attached to this post.")
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
        }
    }
}

struct DiscordInviteEmbedPreview: View {
    let guild: RLGuildDTO?
    let inviteURL: URL?

    var body: some View {
        DiscordEmbedFrame {
            HStack(spacing: 12) {
                if let guild {
                    GuildCrestView(guild: guild, size: 42)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Join \(guild?.name ?? "this guild") on Traders Guild")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.whiteText)
                    Text("Trade together, share markers, and follow the market as a guild.")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if let inviteURL {
                Text(inviteURL.absoluteString)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.guildReputationAccent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

private struct DiscordEmbedFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image("DiscordLogo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(AppColors.whiteText)
                Text("Traders Guild")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.whiteText)
                Text("APP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.whiteText)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.35, green: 0.39, blue: 0.95)))
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.guildReputationAccent)
                    .frame(width: 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.13, blue: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
    }
}
