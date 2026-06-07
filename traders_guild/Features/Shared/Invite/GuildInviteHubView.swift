//
//  GuildInviteHubView.swift
//  traders_guild
//
//  The single, reusable "bring your community in" hub. Used after guild
//  creation, from the owner drawer promo, in the signup invite step, and from
//  the User List "Refer Friends" button. Generates the guild's invite link and
//  offers channel-specific sharing (X, Discord, Messages, Copy, QR, More).
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

    @State private var inviteURL: URL?
    @State private var isLoadingLink = true
    @State private var showQRSheet = false
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            primaryButton
        }
        .background(AppColors.gradientBackgroundDark.opacity(0.96).ignoresSafeArea())
        .task(id: rlAppState.currentGuild?.id) { await ensureInviteLink() }
        .sheet(isPresented: $showQRSheet, onDismiss: { busyChannel = nil }) {
            qrSheet
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
                shareToDiscord()
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

    private func shareToDiscord() {
        guard let url = inviteURL else { return }
        // Discord has no pre-filled compose deep link, so copy a ready-made
        // message and open the app for the user to paste into their server.
        UIPasteboard.general.string = GuildInviteShare.discordMessage(guildName: guildName, url: url)
        rlAppState.showSuccess("Message copied — paste it into Discord")
        GuildInviteShare.openAppOrWeb(
            GuildInviteShare.discordAppURL,
            fallback: GuildInviteShare.discordWebURL
        )
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
