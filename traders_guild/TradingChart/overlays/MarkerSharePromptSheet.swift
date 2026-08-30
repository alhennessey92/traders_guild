//
//  MarkerSharePromptSheet.swift
//  traders_guild
//
//  Branded bottom sheet shown right after a guild-visible marker is placed,
//  offering to share it: to guild members via DM, to X, copy link, or the
//  native share sheet. Mirrors GuildInviteHubView's channel styling and reuses
//  MarkerShareKit / GuildInviteShare for the channel actions.
//

import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted by the chart after a guild-visible marker is placed. MainView
    /// presents `MarkerSharePromptSheet` in response so it stacks above the
    /// always-present chart bottom sheet — a sheet presented from inside the
    /// chart contends with that one and floods the log on every live tick.
    static let presentMarkerSharePrompt = Notification.Name("presentMarkerSharePrompt")
}

/// userInfo key carrying the `MarkerShareContext` on `.presentMarkerSharePrompt`.
enum MarkerSharePromptNotification {
    static let contextKey = "shareContext"
}

/// `.sheet(item:)` payload describing the marker to share.
struct MarkerShareContext: Identifiable {
    let id = UUID()
    let marker: RLChartMarkerDTO
    let symbolTicker: String?
    let isNewPlacement: Bool
    let isCurrentUserMarker: Bool

    init(
        marker: RLChartMarkerDTO,
        symbolTicker: String?,
        isNewPlacement: Bool = true,
        isCurrentUserMarker: Bool? = nil
    ) {
        self.marker = marker
        self.symbolTicker = symbolTicker
        self.isNewPlacement = isNewPlacement
        self.isCurrentUserMarker = isCurrentUserMarker ?? marker.isCurrentUserMarker
    }

    var canShareWithinGuild: Bool {
        MarkerShare.canShareWithinGuild(visibility: marker.visibility)
    }

    var canShareExternally: Bool {
        MarkerShare.canShareExternally(
            isCurrentUserMarker: isCurrentUserMarker,
            visibility: marker.visibility
        )
    }

    var sheetTitle: String { isNewPlacement ? "Marker placed" : "Share marker" }

    var sheetSubtitle: String {
        if isNewPlacement {
            return "Keep it in your guild or choose an external destination."
        }
        if canShareExternally {
            return "Choose an in-app or external destination."
        }
        return "Send this guild marker to another guild member."
    }
}

struct MarkerSharePromptSheet: View {
    let context: MarkerShareContext
    @ObservedObject var appState: RLAppState

    @Environment(\.dismiss) private var dismiss
    @State private var showRecipientPicker = false
    @State private var showDiscordDestination = false
    @State private var caption = ""
    @State private var discordChannels: [RLGuildDiscordChannelDTO] = []
    @State private var selectedDiscordChannelId: UUID?
    @State private var busyChannel: ChannelKind?
    @State private var externalShareURL: URL?

    private enum ChannelKind { case guildDM, discord, x, telegram, reddit, copy, more }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.surfaceWhite20)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            VStack(spacing: 6) {
                Text(context.sheetTitle)
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text(context.sheetSubtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 16)

            TextField("Add a message (optional)", text: $caption, axis: .vertical)
                .lineLimit(1...3)
                .textInputAutocapitalization(.sentences)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.surfaceWhite08)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .onChange(of: caption) { _, newValue in
                    if newValue.count > 280 { caption = String(newValue.prefix(280)) }
                }

            channelGrid
                .padding(.horizontal, 18)

            if context.canShareExternally {
                Label {
                    Text(MarkerShare.externalSharingDisclosure)
                } icon: {
                    Image(systemName: "globe")
                }
                .font(.caption2)
                .foregroundColor(AppColors.secondaryForeground)
                .padding(.horizontal, 24)
                .padding(.top, 14)
            }

            Spacer(minLength: 12)

            Button { dismiss() } label: {
                Text("Not now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.secondaryForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(InvitePressStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.sheetBackground.ignoresSafeArea())
        .presentationDetents([.height(context.canShareExternally ? 560 : 390)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .task {
            await loadDiscordState()
        }
        .sheet(isPresented: $showRecipientPicker) {
            MarkerDMRecipientPicker(
                marker: context.marker,
                symbolTicker: context.symbolTicker,
                caption: caption,
                appState: appState
            ) {
                // After the picker sends/cancels, close the whole prompt too.
                dismiss()
            }
        }
        .sheet(isPresented: $showDiscordDestination) {
            DiscordDestinationSheet(
                title: "Share marker",
                channels: discordChannels,
                selectedChannelId: $selectedDiscordChannelId,
                isPosting: busyChannel == .discord,
                preview: {
                    DiscordMarkerEmbedPreview(
                        symbolTicker: context.symbolTicker,
                        timeframe: context.marker.timeframe,
                        timestamp: context.marker.candleTimestamp,
                        intent: context.marker.intentEnum,
                        alertSeverity: context.marker.alertSeverity.flatMap(MarkerAlertSeverity.fromBackendString),
                        emoji: context.marker.selectedEmoji,
                        caption: caption
                    )
                },
                onPost: { Task { await postToSelectedDiscordChannel() } },
                onCopyAndOpen: { Task { await copyForDiscordAndOpen() } }
            )
        }
    }

    // MARK: - Channels

    @ViewBuilder
    private var channelGrid: some View {
        // Four columns, not three: seven channels still land in two rows, so the
        // sheet keeps its height instead of growing a third.
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
        if context.canShareExternally {
            LazyVGrid(columns: columns, spacing: 12) {
                channel(kind: .guildDM, label: "Guild DM", spec: ShareChannelStyle.guildDM) {
                    showRecipientPicker = true
                }
                // Posting to Discord means posting to the *guild's* channel, so
                // it only makes sense for markers the guild can see.
                channel(
                    kind: .discord,
                    label: discordLabel,
                    spec: ShareChannelStyle.discord,
                    badge: discordChannels.contains(where: \.needsAttention)
                        ? "exclamationmark.circle.fill"
                        : nil
                ) {
                    Task { await prepareDiscordShare() }
                }
                channel(kind: .x, label: "X", spec: ShareChannelStyle.x) {
                    Task { await shareToX() }
                }
                channel(kind: .telegram, label: "Telegram", spec: ShareChannelStyle.telegram) {
                    Task { await shareToTelegram() }
                }
                channel(kind: .reddit, label: "Reddit", spec: ShareChannelStyle.reddit) {
                    Task { await shareToReddit() }
                }
                channel(kind: .copy, label: "Copy link", spec: ShareChannelStyle.copyLink) {
                    Task { await copyLink() }
                }
                channel(kind: .more, label: "More", spec: ShareChannelStyle.more) {
                    Task { await shareMore() }
                }
            }
        } else if context.canShareWithinGuild {
            HStack {
                Spacer()
                channel(kind: .guildDM, label: "Guild DM", spec: ShareChannelStyle.guildDM) {
                    showRecipientPicker = true
                }
                .frame(width: 104)
                Spacer()
            }
        }
    }

    /// "Discord" once we know a webhook is connected; the generic label until then.
    private var discordLabel: String {
        discordChannels.contains(where: \.canPost) ? "Guild Discord" : "Discord"
    }

    /// A channel tile. The mark comes from `ShareChannelStyle` so this sheet and
    /// the invite hub cannot drift apart again; only the container is local.
    private func channel(
        kind: ChannelKind,
        label: String,
        spec: ShareChannelSpec,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppColors.surfaceWhite08)
                        .frame(width: 58, height: 58)
                    if busyChannel == kind {
                        ProgressView().tint(AppColors.primaryForeground)
                    } else {
                        ShareChannelMark(spec: spec)
                    }

                    if let badge, busyChannel != kind {
                        Image(systemName: badge)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.statusWarning)
                            .background(Circle().fill(AppColors.sheetBackground))
                            .offset(x: 20, y: -20)
                    }
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryForeground)
                    .lineLimit(1)
                    // Four columns leaves ~78pt a cell on a 375pt screen, and the
                    // longest label ("Guild Discord") needs the extra headroom.
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(InvitePressStyle())
        .disabled(busyChannel != nil)
    }

    // MARK: - Actions

    private func loadDiscordState() async {
        guard context.canShareExternally, discordChannels.isEmpty else { return }
        // Best-effort: a failure just leaves the copy-and-open fallback in place.
        if let response = try? await appState.realApi.getGuildDiscordChannels(
            guildId: context.marker.guildId
        ) {
            discordChannels = response.channels
            selectedDiscordChannelId = response.preferredChannel?.id
        }
    }

    private func loadExternalShareURL() async -> URL? {
        guard context.canShareExternally else { return nil }
        if let externalShareURL { return externalShareURL }
        do {
            let response = try await appState.realApi.createMarkerExternalShareLink(
                guildId: context.marker.guildId,
                markerId: context.marker.id
            )
            guard let url = MarkerShare.validatedServerShareURL(
                response.shareUrl,
                markerId: context.marker.id
            ) else {
                appState.showError(
                    title: "Couldn't create share link",
                    message: "The server returned an invalid marker link. Please try again.",
                    style: .toast
                )
                return nil
            }
            externalShareURL = url
            return url
        } catch {
            appState.showError(
                title: "Couldn't create share link",
                message: "Check your connection and try again.",
                style: .toast
            )
            return nil
        }
    }

    private func shareToX() async {
        guard context.canShareExternally else { return }
        busyChannel = .x
        defer { busyChannel = nil }
        guard let shareURL = await loadExternalShareURL() else { return }
        GuildInviteShare.openAppOrWeb(
            MarkerShare.xAppURL(
                symbolTicker: context.symbolTicker,
                caption: caption,
                url: shareURL,
                intent: context.marker.intent,
                price: context.marker.price
            ),
            fallback: MarkerShare.xComposeURL(
                symbolTicker: context.symbolTicker,
                caption: caption,
                url: shareURL,
                intent: context.marker.intent,
                price: context.marker.price
            )
        )
        dismiss()
    }

    private func shareToTelegram() async {
        guard context.canShareExternally else { return }
        busyChannel = .telegram
        defer { busyChannel = nil }
        guard let shareURL = await loadExternalShareURL() else { return }
        GuildInviteShare.openAppOrWeb(
            MarkerShare.telegramAppURL(
                symbolTicker: context.symbolTicker,
                caption: caption,
                url: shareURL,
                intent: context.marker.intent,
                price: context.marker.price
            ),
            fallback: MarkerShare.telegramWebURL(
                symbolTicker: context.symbolTicker,
                caption: caption,
                url: shareURL,
                intent: context.marker.intent,
                price: context.marker.price
            )
        )
        dismiss()
    }

    private func shareToReddit() async {
        guard context.canShareExternally else { return }
        busyChannel = .reddit
        defer { busyChannel = nil }
        guard let shareURL = await loadExternalShareURL() else { return }
        // No app scheme to try first — Reddit claims its submit page as a
        // universal link, so an installed app catches this itself.
        GuildInviteShare.open(
            MarkerShare.redditSubmitURL(
                symbolTicker: context.symbolTicker,
                caption: caption,
                url: shareURL,
                intent: context.marker.intent,
                price: context.marker.price
            )
        )
        dismiss()
    }

    private func prepareDiscordShare() async {
        guard context.canShareExternally else { return }
        busyChannel = .discord
        guard await loadExternalShareURL() != nil else {
            busyChannel = nil
            return
        }
        await loadDiscordState()
        busyChannel = nil

        let response = RLGuildDiscordChannelsListDTO(channels: discordChannels)
        // No bypass when the guild has no connected channel: the sheet says so
        // and offers the copy-and-paste path. Jumping straight to Discord left
        // people on its home screen with a clipboard they didn't know was full.
        if !discordChannels.contains(where: { $0.id == selectedDiscordChannelId && $0.canPost }) {
            selectedDiscordChannelId = response.preferredChannel?.id
        }
        showDiscordDestination = true
    }

    private func postToSelectedDiscordChannel() async {
        guard context.canShareExternally else { return }
        guard let channel = discordChannels.first(where: {
            $0.id == selectedDiscordChannelId && $0.canPost
        }) else { return }
        busyChannel = .discord
        defer { busyChannel = nil }
        do {
            try await appState.realApi.shareMarkerToDiscord(
                guildId: context.marker.guildId,
                markerId: context.marker.id,
                channelId: channel.id,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : caption
            )
            showDiscordDestination = false
            appState.showSuccess("Posted to \(channel.displayLabel)")
            dismiss()
        } catch {
            // The webhook may have been revoked in Discord since we last looked;
            // don't dead-end the user — hand them the paste-it-yourself path.
            appState.showError(
                title: "Couldn't post to Discord",
                message: "Your message was copied — paste it into your channel.",
                style: .toast
            )
            await copyForDiscordAndOpen()
        }
    }

    private func copyForDiscordAndOpen() async {
        guard context.canShareExternally,
              let shareURL = await loadExternalShareURL() else { return }
        showDiscordDestination = false
        UIPasteboard.general.string = MarkerShare.discordMessage(
            symbolTicker: context.symbolTicker,
            caption: caption,
            url: shareURL,
            intent: context.marker.intent,
            price: context.marker.price
        )
        GuildInviteShare.openAppOrWeb(
            MarkerShare.discordAppURL,
            fallback: MarkerShare.discordWebURL
        )
        dismiss()
    }

    private func copyLink() async {
        guard context.canShareExternally else { return }
        busyChannel = .copy
        defer { busyChannel = nil }
        guard let shareURL = await loadExternalShareURL() else { return }
        UIPasteboard.general.string = shareURL.absoluteString
        appState.showSuccess("Marker link copied")
        dismiss()
    }

    private func shareMore() async {
        guard context.canShareExternally else { return }
        busyChannel = .more
        defer { busyChannel = nil }
        guard let shareURL = await loadExternalShareURL() else { return }
        // Presented via UIKit on top of this sheet (same approach as the invite
        // hub) — do NOT dismiss first, or the activity sheet is torn down with us.
        let item = MarkerShareItem(url: shareURL, symbolTicker: context.symbolTicker, caption: caption)
        MarkerShare.presentNativeShareSheet(for: item)
    }
}
