//
//  GuildInviteHubView.swift
//  traders_guild
//
//  The single, reusable "bring your community in" hub. Used after guild
//  creation, from the owner drawer promo, and from the User List "Refer
//  Friends" button. Generates the guild's invite link and offers
//  channel-specific sharing (X, Discord, Messages, Copy, QR, More).
//

import SwiftUI
import UIKit

struct GuildInviteHubView: View {
    // Customisation points so the same hub fits every surface.
    var headline: String = "Invite your community"
    var subheadline: String = "Share your guild and bring traders in from X, Discord, and your contacts."
    var primaryButtonTitle: String = "Done"
    /// When provided, the bottom button calls this (e.g. advance signup step).
    /// When nil, it dismisses the presented sheet.
    var onPrimaryAction: (() -> Void)? = nil

    /// What link the hub shares:
    /// - `.referral` — a member referring friends → `/invite/{code}` (earns reputation).
    /// - `.guildVanity` — an owner inviting to their guild → `/g/{slug}` (no reputation).
    enum ShareMode { case referral, guildVanity }
    var shareMode: ShareMode = .referral

    @EnvironmentObject var rlAppState: RLAppState
    @Environment(\.dismiss) private var dismiss
    /// Sharing leaves no server-side trace, so this tracks it for the session
    /// only. Resetting on reopen is the honest default: we don't know they did.
    @State private var hasShared = false
    @State private var showGuildSettings = false

    @State private var inviteURL: URL?
    /// Referral code behind `inviteURL`, needed to post the invite to Discord.
    @State private var inviteCode: String?
    /// Direct Discord posts always use a server-validated invite code. In
    /// vanity mode the visible share link remains `/g/{slug}` while this is
    /// prepared lazily only after the user chooses Discord.
    @State private var discordInviteURL: URL?
    @State private var isLoadingLink = true
    @State private var showQRSheet = false
    @State private var discordChannels: [RLGuildDiscordChannelDTO] = []
    @State private var selectedDiscordChannelId: UUID?
    @State private var showDiscordDestination = false
    /// Channel whose action is being prepared (shows a spinner in its button).
    @State private var busyChannel: ChannelKind?
    /// Channel currently showing a tap pulse (action-driven press feedback).
    @State private var pulseChannel: ChannelKind?

    private var guild: RLGuildDTO? { rlAppState.currentGuild }
    private var guildName: String { guild?.name ?? "your guild" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    guildCard
                    channelGrid
                    // In vanity mode the slug IS the shared link, so the address
                    // row would be redundant; only show it for referral sharing.
                    if shareMode == .referral, let handle = guild?.shareURL {
                        guildAddressRow(handle)
                    }
                    // Owner-facing only: creation now asks for a name alone, so
                    // this is the path to everything it stopped asking for.
                    if shareMode == .guildVanity {
                        setupChecklist
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            primaryButton
        }
        .background(AppColors.gradientBackgroundDark.opacity(0.96).ignoresSafeArea())
        .task(id: rlAppState.currentGuild?.id) { await ensureInviteLink() }
        .task(id: rlAppState.currentGuild?.id) { await loadDiscordChannels() }
        .sheet(isPresented: $showQRSheet, onDismiss: { busyChannel = nil }) {
            qrSheet
        }
        .sheet(isPresented: $showDiscordDestination) {
            DiscordDestinationSheet(
                title: "Share guild invite",
                channels: discordChannels,
                selectedChannelId: $selectedDiscordChannelId,
                isPosting: busyChannel == .discord,
                preview: {
                    DiscordInviteEmbedPreview(
                        guild: guild,
                        inviteURL: discordInviteURL ?? inviteURL
                    )
                },
                onPost: { Task { await postInviteToDiscord() } },
                onCopyAndOpen: { copyForDiscordAndOpen() }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.friendAccent.opacity(0.95), AppColors.statusPositive70.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(AppColors.onAccentForeground)
            }

            Text(headline)
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.whiteText)
                .multilineTextAlignment(.center)

            Text(subheadline)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Guild + link card

    private var guildCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                if let guild {
                    GuildCrestView(guild: guild, size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(guildName)
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.whiteText)
                        .lineLimit(1)
                    Text(shareMode == .guildVanity ? "Your guild's link" : "Your guild invite link")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                Spacer()
            }

            // Link row with copy
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.guildReputationAccent)

                Group {
                    if isLoadingLink && inviteURL == nil {
                        Text("Preparing your link…")
                            .foregroundColor(AppColors.greyText)
                    } else {
                        Text(inviteURL?.absoluteString ?? "Link unavailable")
                            .foregroundColor(AppColors.whiteText)
                    }
                }
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

                Spacer(minLength: 4)

                if isLoadingLink && inviteURL == nil {
                    ProgressView().scaleEffect(0.7).tint(AppColors.guildReputationAccent)
                } else {
                    Button {
                        copyInviteLink()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.guildReputationAccent)
                    }
                    .buttonStyle(InvitePressStyle())
                    .disabled(inviteURL == nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.adaptiveFormControlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.adaptiveFormControlStroke, lineWidth: 1)
                    )
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.gradientBackgroundDark.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.whiteText.opacity(0.14), lineWidth: 1)
                )
        )
    }

    // MARK: - Channels

    private enum ChannelIcon {
        case system(String)
        case asset(String)
    }

    private enum ChannelKind {
        case x, discord, messages, copy, qr, more
    }

    private var channelGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            channelButton(kind: .x, title: "X", icon: .asset("XLogo"), tint: AppColors.whiteText) {
                shareToX()
            }
            channelButton(kind: .discord, title: "Discord", icon: .asset("DiscordLogo"), tint: AppColors.whiteText) {
                Task { await prepareDiscordShare() }
            }
            channelButton(kind: .messages, title: "Messages", icon: .system("message.fill"), tint: AppColors.statusPositive70) {
                shareViaMessages()
            }
            channelButton(kind: .copy, title: "Copy link", icon: .system("doc.on.doc.fill"), tint: AppColors.guildReputationAccent) {
                copyInviteLink()
            }
            channelButton(kind: .qr, title: "QR code", icon: .system("qrcode"), tint: AppColors.whiteText) {
                // Spinner is shown immediately by fireChannel; cleared in qrSheet.
                showQRSheet = true
            }
            channelButton(kind: .more, title: "More", icon: .system("square.and.arrow.up"), tint: AppColors.friendAccent) {
                shareMore()
            }
        }
    }

    private func channelButton(
        kind: ChannelKind,
        title: String,
        icon: ChannelIcon,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            fireChannel(kind, action)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.whiteText.opacity(pulseChannel == kind ? 0.18 : 0.08))
                        .frame(height: 56)
                    if busyChannel == kind {
                        ProgressView()
                            .tint(AppColors.whiteText)
                    } else {
                        channelIcon(icon, tint: tint)
                    }
                }
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(1)
            }
            .scaleEffect(pulseChannel == kind ? 0.88 : 1)
        }
        .buttonStyle(.plain)
        .disabled(inviteURL == nil || busyChannel != nil)
        .opacity(inviteURL == nil ? 0.5 : 1)
    }

    @ViewBuilder
    private func channelIcon(_ icon: ChannelIcon, tint: Color) -> some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(tint)
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
    }

    private func guildAddressRow(_ handle: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.greyText)
            VStack(alignment: .leading, spacing: 1) {
                Text("Guild address")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                Text(handle.absoluteString.replacingOccurrences(of: "https://", with: ""))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = handle.absoluteString
                rlAppState.showSuccess("Guild address copied")
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.guildReputationAccent)
            }
            .buttonStyle(InvitePressStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.whiteText.opacity(0.05))
        )
    }

    // MARK: - Primary button

    /// What a newly created guild still needs.
    ///
    /// Creation dropped to a single field, which is only an improvement if
    /// there's an obvious path to the rest — otherwise the result is a nameless
    /// shell, worse than the long form it replaced. Completion is derived from
    /// guild state rather than stored, so it stays honest wherever the owner
    /// does the work.
    @ViewBuilder
    private var setupChecklist: some View {
        // Every row navigates. A checklist you can't act on is a nag list, so a
        // step only earns its place here if tapping it does something.
        let steps: [(title: String, subtitle: String, done: Bool, action: () -> Void)] = [
            // Share goes through fireChannel, the same path the More button
            // uses. Calling shareMore() directly was a second, subtly different
            // route into UIKit presentation — no press delay, no busy state —
            // and it crashed on tap.
            ("Share your guild", "Post the link in your Discord or on X", hasShared,
             { fireChannel(.more) { shareMore() } }),
            // One row, one destination. Two rows into the same sheet reads as a
            // mistake, which is exactly how it looked.
            ("Add a crest and description", "How your guild looks in shares and link previews",
             !(guild?.imageUrl?.isEmpty ?? true)
                && !((guild?.description ?? "").trimmingCharacters(in: .whitespaces).isEmpty),
             { showGuildSettings = true }),
        ]
        let remaining = steps.filter { !$0.done }.count

        if remaining > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Finish setting up")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.whiteText)
                    Spacer()
                    Text("\(steps.count - remaining)/\(steps.count)")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                ForEach(steps.indices, id: \.self) { index in
                    let step = steps[index]
                    Button(action: step.action) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(step.done
                                      ? AppColors.bullCandleGreen
                                      : AppColors.whiteText.opacity(0.10))
                                .frame(width: 22, height: 22)
                            if step.done {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(AppColors.onAccentForeground)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(step.done ? AppColors.greyText : AppColors.whiteText)
                            Text(step.subtitle)
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.whiteText.opacity(0.05))
                    )
                    }
                    .buttonStyle(InvitePressStyle())
                }
            }
            .sheet(isPresented: $showGuildSettings) {
                GuildSettingsView()
                    .environmentObject(rlAppState)
            }
        }
    }


    private var primaryButton: some View {
        Button {
            if let onPrimaryAction {
                onPrimaryAction()
            } else {
                dismiss()
            }
        } label: {
            Text(primaryButtonTitle)
                .font(.headline.weight(.bold))
                .foregroundColor(AppColors.onAccentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.tgAccent)
                )
        }
        .buttonStyle(InvitePressStyle())
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - QR sheet

    private var qrSheet: some View {
        VStack(spacing: 20) {
            Text("Scan to join \(guildName)")
                .font(.headline.weight(.bold))
                .foregroundColor(AppColors.whiteText)
                .multilineTextAlignment(.center)

            if let url = inviteURL, let qr = GuildInviteShare.qrCode(for: url.absoluteString) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 240, height: 240)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
            } else {
                ProgressView().tint(AppColors.whiteText)
            }

            Text("Point a camera at this code to open the guild invite.")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .multilineTextAlignment(.center)

            Button("Done") { showQRSheet = false }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.guildReputationAccent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.gradientBackgroundDark.opacity(0.98).ignoresSafeArea())
        .presentationDetents([.medium])
        .onAppear { busyChannel = nil }
    }

    // MARK: - Actions

    private func ensureInviteLink() async {
        guard inviteURL == nil, let guild else {
            isLoadingLink = false
            return
        }
        // Owner/guild surfaces share the clean vanity address (`/g/{slug}`) — no
        // reputation is awarded, and no API call is needed.
        if shareMode == .guildVanity, let vanity = guild.shareURL {
            inviteURL = vanity
            isLoadingLink = false
            return
        }
        isLoadingLink = true
        defer { isLoadingLink = false }
        do {
            // Referral link (`/invite/{code}`) — credits the sharer's reputation.
            // Call the API directly to avoid the wrapper's success toast firing
            // every time the hub appears.
            let link = try await rlAppState.realApi.createGuildInviteLink(guildId: guild.id)
            inviteURL = URL(string: link.shareUrl)
            discordInviteURL = inviteURL
            // Kept so the invite can be posted to Discord by code.
            inviteCode = link.code
        } catch {
            // Surface a single, quiet failure; channel buttons stay disabled.
            rlAppState.showInfo("Couldn't prepare your invite link. Pull to retry.")
        }
    }

    /// Immediate tap feedback for a channel button — a light haptic + a quick
    /// scale/brightness pulse — then run the action. Action-driven (not press
    /// state) so it fires reliably inside the scroll view and on the simulator.
    private func fireChannel(_ kind: ChannelKind, _ action: @escaping () -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.09)) { pulseChannel = kind }
        // The slow channels (QR/More build + present a sheet) get their spinner
        // immediately, so the wait is obvious from the instant of the tap.
        if kind == .qr || kind == .more {
            hasShared = true
            busyChannel = kind
        }
        // Run the action a beat later so the press-in is actually visible before
        // the app switches to X/Discord or a share/QR sheet covers the screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { pulseChannel = nil }
            action()
        }
    }

    private func copyInviteLink() {
        guard let url = inviteURL else { return }
        UIPasteboard.general.string = url.absoluteString
        rlAppState.showSuccess("Invite link copied")
    }

    private func shareToX() {
        guard let url = inviteURL else { return }
        // Open the X app's composer first; fall back to the web composer.
        GuildInviteShare.openAppOrWeb(
            GuildInviteShare.xAppURL(guildName: guildName, url: url),
            fallback: GuildInviteShare.xComposeURL(guildName: guildName, url: url)
        )
    }

    private func prepareDiscordShare() async {
        busyChannel = .discord
        await loadDiscordChannels()
        busyChannel = nil

        let response = RLGuildDiscordChannelsListDTO(channels: discordChannels)
        // No bypass when the guild has no connected channel: the sheet says so
        // and offers the copy-and-paste path. Jumping straight to Discord left
        // people on its home screen with a clipboard they didn't know was full.

        if !discordChannels.contains(where: { $0.id == selectedDiscordChannelId && $0.canPost }) {
            selectedDiscordChannelId = response.preferredChannel?.id
        }

        // The direct endpoint accepts an invite code, not a vanity slug. Avoid
        // creating a referral link merely by opening the hub; prepare it only
        // when the user explicitly asks for a direct Discord post.
        if inviteCode == nil, let guild {
            busyChannel = .discord
            defer { busyChannel = nil }
            do {
                let link = try await rlAppState.realApi.createGuildInviteLink(guildId: guild.id)
                inviteCode = link.code
                discordInviteURL = URL(string: link.shareUrl)
            } catch {
                rlAppState.showError(error, title: "Couldn't prepare the Discord invite", style: .toast)
                copyForDiscordAndOpen()
                return
            }
        }

        guard inviteCode != nil else {
            copyForDiscordAndOpen()
            return
        }
        showDiscordDestination = true
    }

    /// Copy a ready-made message and open Discord for the user to paste.
    private func copyForDiscordAndOpen() {
        guard let url = inviteURL else { return }
        showDiscordDestination = false
        UIPasteboard.general.string = GuildInviteShare.discordMessage(guildName: guildName, url: url)
        rlAppState.showSuccess("Message copied — paste it into Discord")
        GuildInviteShare.openAppOrWeb(
            GuildInviteShare.discordAppURL,
            fallback: GuildInviteShare.discordWebURL
        )
    }

    /// Post the invite into the guild's connected Discord channel.
    private func postInviteToDiscord() async {
        guard let guildId = guild?.id,
              let code = inviteCode,
              let channel = discordChannels.first(where: {
                  $0.id == selectedDiscordChannelId && $0.canPost
              }) else { return }
        busyChannel = .discord
        defer { busyChannel = nil }
        do {
            try await rlAppState.realApi.shareInviteToDiscord(
                guildId: guildId,
                channelId: channel.id,
                code: code
            )
            showDiscordDestination = false
            rlAppState.showSuccess("Invite posted to \(channel.displayLabel)")
        } catch {
            rlAppState.showError(
                title: "Couldn't post to Discord",
                message: "Your message was copied — paste it into your channel.",
                style: .toast
            )
            copyForDiscordAndOpen()
        }
    }

    private func loadDiscordChannels() async {
        guard let guildId = guild?.id, discordChannels.isEmpty else { return }
        if let response = try? await rlAppState.realApi.getGuildDiscordChannels(guildId: guildId) {
            discordChannels = response.channels
            selectedDiscordChannelId = response.preferredChannel?.id
        }
    }

    private func shareViaMessages() {
        guard let url = inviteURL else { return }
        let body = "Join \(guildName) on Traders Guild: \(url.absoluteString)"
        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        GuildInviteShare.open(URL(string: "sms:&body=\(encoded)"))
    }

    private func shareMore() {
        guard let url = inviteURL else { busyChannel = nil; return }
        // Spinner already shown by fireChannel; clear it once the sheet presents.
        let item = GuildInviteShareItem(url: url, guildName: guildName)
        GuildInviteShare.presentNativeShareSheet(for: item) {
            busyChannel = nil
        }
    }
}

/// Tap feedback for the invite buttons — a subtle press-in scale/dim plus a
/// light haptic, so taps register even when the action takes a moment.
struct InvitePressStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            // Snap in instantly, spring back on release so even a quick tap shows.
            .animation(configuration.isPressed ? nil : .spring(response: 0.3, dampingFraction: 0.5),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}
