//
//  LeaderboardShareKit.swift
//  traders_guild
//
//  Getting a guild's standings out of the app and in front of the people who
//  would care about them.
//
//  The standings are the answer to "who in this community actually calls it
//  best", and that question is most interesting to the Discord the guild grew
//  out of. So the destinations here lead with Discord, and the copy is written
//  to be posted rather than read in place.
//

import SwiftUI
import UIKit

enum LeaderboardShare {
    /// The public standings page, when the guild publishes one.
    ///
    /// Without it there is nothing an outsider could open, so the share sheet
    /// offers the guild's own page instead of a link that would 404.
    /// The element id the page gives one trader's row.
    ///
    /// Must stay identical to `leaderboard_anchor` in the backend's
    /// `public_invites.py` — the app appends this as the URL fragment and the
    /// server stamps it on the row, and a mismatch means the browser silently
    /// does not scroll.
    static func anchor(for handle: String?) -> String {
        let lowered = (handle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        let kept = lowered.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return kept.isEmpty ? "" : "trader-\(kept)"
    }

    /// `trader` highlights that member's row — and pins it below the page when
    /// they rank past it — while the fragment scrolls the browser to it. Both
    /// are needed: the query decides what is rendered, the fragment decides
    /// where the reader lands.
    static func publicURL(
        slug: String?, window: LeaderboardWindow, trader: String? = nil
    ) -> URL? {
        guard let slug, !slug.isEmpty else { return nil }
        var components = URLComponents(
            string: "https://tradersguild.co/g/\(slug)/leaderboard"
        )
        var items: [URLQueryItem] = []
        if window != .all {
            items.append(URLQueryItem(name: "window", value: window.rawValue))
        }
        let handle = (trader ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        if !handle.isEmpty {
            items.append(URLQueryItem(name: "trader", value: handle))
        }
        components?.queryItems = items.isEmpty ? nil : items
        let fragment = anchor(for: trader)
        if !fragment.isEmpty {
            components?.fragment = fragment
        }
        return components?.url
    }

    /// One line naming who is ahead — the whole reason to post standings.
    static func headline(
        guildName: String,
        window: LeaderboardWindow,
        leader: RLAccuracyLeaderboardMemberDTO?
    ) -> String {
        guard let leader else {
            return "\(guildName) · \(window.caption.lowercased()) accuracy standings"
        }
        let name = leader.displayName.isEmpty ? leader.username : leader.displayName
        let accuracy = Int((leader.accuracyRate * 100).rounded())
        let losses = max(0, leader.totalPredictions - leader.successfulPredictions)
        return "\(name) leads \(guildName) on \(accuracy)% accuracy "
            + "(\(leader.successfulPredictions)W · \(losses)L) over the \(window.caption.lowercased())."
    }

    /// Body text for X / Telegram / the system sheet.
    static func message(
        guildName: String,
        window: LeaderboardWindow,
        leader: RLAccuracyLeaderboardMemberDTO?,
        url: URL?
    ) -> String {
        var parts = [headline(guildName: guildName, window: window, leader: leader)]
        parts.append("Every tracked setup is scored automatically when it hits its target or stop.")
        if let url {
            parts.append(url.absoluteString)
        }
        return parts.joined(separator: "\n\n")
    }

    /// `MarkerShareKit`'s composers are marker-shaped — they build their text
    /// from a ticker, price and outcome — so standings get their own two-line
    /// equivalents rather than a ticker-less marker share.
    static func xComposeURL(text: String) -> URL? {
        var components = URLComponents(string: "https://x.com/intent/tweet")
        components?.queryItems = [URLQueryItem(name: "text", value: text)]
        return components?.url
    }

    /// Native X composer, tried before the web one — same fallback pair the
    /// invite hub and the marker sheet use.
    static func xAppURL(text: String) -> URL? {
        var components = URLComponents()
        components.scheme = "twitter"
        components.host = "post"
        components.queryItems = [URLQueryItem(name: "message", value: text)]
        return components.url
    }

    static func telegramURL(text: String, url: URL?) -> URL? {
        var components = URLComponents(string: "https://t.me/share/url")
        components?.queryItems = telegramQueryItems(text: text, url: url)
        return components?.url
    }

    static func telegramAppURL(text: String, url: URL?) -> URL? {
        var components = URLComponents()
        components.scheme = "tg"
        components.host = "msg_url"
        components.queryItems = telegramQueryItems(text: text, url: url)
        return components.url
    }

    private static func telegramQueryItems(text: String, url: URL?) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "text", value: text)]
        // Telegram wants the link in `url`; without one it still posts the text.
        if let url {
            items.insert(URLQueryItem(name: "url", value: url.absoluteString), at: 0)
        }
        return items
    }

    /// A link post is a title plus a URL, so the headline doubles as the title.
    /// Nothing to post without a link — Reddit has no text-only submit URL.
    static func redditSubmitURL(title: String, url: URL?) -> URL? {
        guard let url else { return nil }
        var components = URLComponents(string: "https://www.reddit.com/submit")
        components?.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(
                name: "title", value: String(title.prefix(MarkerShare.redditTitleLimit))
            ),
        ]
        return components?.url
    }

    /// The system share sheet, presented from the topmost controller.
    static func presentSystemShareSheet(text: String, url: URL?) {
        var items: [Any] = [text]
        if let url {
            items.append(url)
        }
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            var presenter = scene.keyWindow?.rootViewController
        else { return }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = presenter.view
        controller.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0
        )
        presenter.present(controller, animated: true)
    }
}

extension LeaderboardShare {
    /// One trader's own record, phrased as they would post it.
    /// The record on one line — Reddit takes a title, not a body.
    static func personalHeadline(
        guildName: String,
        profile: RLAccuracyProfileDTO,
        rank: Int?
    ) -> String {
        let accuracy = Int((profile.accuracyRate * 100).rounded())
        let losses = max(0, profile.totalPredictions - profile.successfulPredictions)
        var line = "\(accuracy)% accuracy on \(profile.totalPredictions) tracked setups "
            + "(\(profile.successfulPredictions)W · \(losses)L) in \(guildName)."
        if let rank {
            line += " Ranked #\(rank)."
        }
        return line
    }

    static func personalMessage(
        guildName: String,
        window: LeaderboardWindow,
        profile: RLAccuracyProfileDTO,
        rank: Int?,
        url: URL?
    ) -> String {
        var parts = [personalHeadline(guildName: guildName, profile: profile, rank: rank)]
        parts.append("Every call is scored automatically when it hits its target or stop — no cherry-picking.")
        if let url {
            parts.append(url.absoluteString)
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Share surfaces
//
// Both sheets below are the app's standard share surface: a four-column grid of
// round channel tiles drawn from `ShareChannelStyle`, in `ShareChannel`'s
// canonical order, over a preview of what is about to be posted. They used to
// be a vertical list of their own invention, which meant X sat in a different
// place — and looked like a different app — depending on whether you were
// sharing a marker, an invite or the standings.

/// One channel tile. Identical geometry to `MarkerSharePromptSheet`'s, which is
/// the surface people meet first.
private struct LeaderboardShareTile: View {
    let kind: ShareChannel
    var label: String?
    let isBusy: Bool
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppColors.surfaceWhite08)
                        .frame(width: 58, height: 58)
                    if isBusy {
                        ProgressView().tint(AppColors.primaryForeground)
                    } else {
                        ShareChannelMark(spec: kind.spec)
                    }
                    if let badge, !isBusy {
                        Image(systemName: badge)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.statusPositive70)
                            .background(Circle().fill(AppColors.sheetBackground))
                            .offset(x: 20, y: -20)
                    }
                }
                Text(label ?? kind.title)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(InvitePressStyle())
    }
}

private let leaderboardShareGridColumns = [
    GridItem(.flexible()), GridItem(.flexible()),
    GridItem(.flexible()), GridItem(.flexible()),
]

/// "Share my record" — the same destinations as the standings sheet, minus
/// Discord, which posts the guild's board rather than one person's card.
struct MemberStatsShareSheet: View {
    let guildName: String
    let guildSlug: String?
    let isPublished: Bool
    let window: LeaderboardWindow
    let profile: RLAccuracyProfileDTO
    let rank: Int?
    /// The sharer's handle, so the link opens on their row rather than the
    /// top of a board they may be well down.
    let username: String?

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    /// Reddit needs a link and Discord posts the guild's board, not one card.
    private static let channels: [ShareChannel] = [
        .x, .reddit, .telegram, .copyLink, .more,
    ]

    private var shareURL: URL? {
        isPublished
            ? LeaderboardShare.publicURL(
                slug: guildSlug, window: window, trader: username
            )
            : guildSlug.flatMap { URL(string: "https://tradersguild.co/g/\($0)") }
    }

    private var messageText: String {
        LeaderboardShare.personalMessage(
            guildName: guildName, window: window, profile: profile, rank: rank, url: shareURL
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.surfaceWhite20)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 18)

            VStack(spacing: 6) {
                Text("Share your record")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text("Tracked automatically — which is the only reason anyone should believe it.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            LeaderboardSharePreview(text: messageText)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            LazyVGrid(columns: leaderboardShareGridColumns, spacing: 12) {
                ForEach(Self.channels, id: \.self) { kind in
                    tile(kind)
                }
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 12)

            Button { dismiss() } label: {
                Text("Done")
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
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func tile(_ kind: ShareChannel) -> some View {
        switch kind {
        case .x:
            LeaderboardShareTile(kind: .x, isBusy: false) {
                GuildInviteShare.openAppOrWeb(
                    LeaderboardShare.xAppURL(text: messageText),
                    fallback: LeaderboardShare.xComposeURL(text: messageText)
                )
            }
        case .reddit:
            LeaderboardShareTile(kind: .reddit, isBusy: false) {
                open(
                    LeaderboardShare.redditSubmitURL(
                        title: LeaderboardShare.personalHeadline(
                            guildName: guildName, profile: profile, rank: rank
                        ),
                        url: shareURL
                    )
                )
            }
        case .telegram:
            LeaderboardShareTile(kind: .telegram, isBusy: false) {
                GuildInviteShare.openAppOrWeb(
                    LeaderboardShare.telegramAppURL(text: messageText, url: shareURL),
                    fallback: LeaderboardShare.telegramURL(text: messageText, url: shareURL)
                )
            }
        case .copyLink:
            LeaderboardShareTile(
                kind: .copyLink,
                label: copied ? "Copied" : "Copy",
                isBusy: false,
                badge: copied ? "checkmark.circle.fill" : nil
            ) {
                UIPasteboard.general.string = messageText
                HapticFeedback.success.trigger()
                copied = true
            }
        case .more:
            LeaderboardShareTile(kind: .more, isBusy: false) {
                LeaderboardShare.presentSystemShareSheet(text: messageText, url: shareURL)
            }
        case .discord, .guildDM, .messages, .qrCode:
            EmptyView()
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }
}

/// What is about to be posted, shown before it is.
private struct LeaderboardSharePreview: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(AppColors.whiteText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.insetPanelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
    }
}

/// The share sheet the leaderboard's Share button opens.
struct LeaderboardShareSheet: View {
    let guildId: UUID
    let guildName: String
    let guildSlug: String?
    let isPublished: Bool
    let window: LeaderboardWindow
    let members: [RLAccuracyLeaderboardMemberDTO]
    let channels: [RLGuildDiscordChannelDTO]

    @EnvironmentObject private var rlAppState: RLAppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChannelId: UUID?
    @State private var showDiscordDestination = false
    @State private var busyChannel: ShareChannel?
    @State private var postedLabel: String?
    @State private var copied = false

    /// The canonical top row, then the utilities.
    private static let shareChannels: [ShareChannel] = [
        .x, .discord, .reddit, .telegram, .copyLink, .more,
    ]

    private var usableChannels: [RLGuildDiscordChannelDTO] {
        channels.filter(\.canPost)
    }

    private var leader: RLAccuracyLeaderboardMemberDTO? { members.first }

    private var shareURL: URL? {
        isPublished
            ? LeaderboardShare.publicURL(slug: guildSlug, window: window)
            : guildShareURL
    }

    /// The guild's own page — still a real destination when standings are private.
    private var guildShareURL: URL? {
        guard let slug = guildSlug, !slug.isEmpty else { return nil }
        return URL(string: "https://tradersguild.co/g/\(slug)")
    }

    private var messageText: String {
        LeaderboardShare.message(
            guildName: guildName, window: window, leader: leader, url: shareURL
        )
    }

    private var headline: String {
        LeaderboardShare.headline(guildName: guildName, window: window, leader: leader)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.surfaceWhite20)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 18)

            VStack(spacing: 6) {
                Text("Share standings")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text(window.caption)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryForeground)
            }
            .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    standingsPreview
                    if !isPublished {
                        privateStandingsNote
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 220)
            .padding(.bottom, 18)

            LazyVGrid(columns: leaderboardShareGridColumns, spacing: 12) {
                ForEach(Self.shareChannels, id: \.self) { kind in
                    tile(kind)
                }
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 12)

            Button { dismiss() } label: {
                Text("Done")
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
        // Sized to the content: title, a capped preview, two rows of tiles and
        // Done. 640 overshot it and left dead space on a small phone.
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            selectedChannelId = (usableChannels.first(where: \.isDefault) ?? usableChannels.first)?.id
        }
        .sheet(isPresented: $showDiscordDestination) {
            DiscordDestinationSheet(
                title: "Share standings",
                channels: channels,
                selectedChannelId: $selectedChannelId,
                isPosting: busyChannel == .discord,
                preview: { standingsPreview },
                onPost: { Task { await postToDiscord() } },
                onCopyAndOpen: {
                    UIPasteboard.general.string = messageText
                    HapticFeedback.success.trigger()
                    GuildInviteShare.openAppOrWeb(
                        GuildInviteShare.discordAppURL,
                        fallback: GuildInviteShare.discordWebURL
                    )
                }
            )
            .environmentObject(rlAppState)
        }
    }

    @ViewBuilder
    private func tile(_ kind: ShareChannel) -> some View {
        switch kind {
        case .x:
            LeaderboardShareTile(kind: .x, isBusy: false) {
                GuildInviteShare.openAppOrWeb(
                    LeaderboardShare.xAppURL(text: messageText),
                    fallback: LeaderboardShare.xComposeURL(text: messageText)
                )
            }
        case .discord:
            LeaderboardShareTile(
                kind: .discord,
                label: postedLabel.map { _ in "Posted" }
                    ?? (usableChannels.isEmpty ? "Discord" : "Guild Discord"),
                isBusy: busyChannel == .discord,
                badge: postedLabel != nil ? "checkmark.circle.fill" : nil
            ) {
                // Posting the same board twice into one channel is noise, not
                // reach — the tile stays as its own receipt instead.
                guard postedLabel == nil else { return }
                showDiscordDestination = true
            }
        case .reddit:
            LeaderboardShareTile(kind: .reddit, isBusy: false) {
                open(LeaderboardShare.redditSubmitURL(title: headline, url: shareURL))
            }
        case .telegram:
            LeaderboardShareTile(kind: .telegram, isBusy: false) {
                GuildInviteShare.openAppOrWeb(
                    LeaderboardShare.telegramAppURL(text: messageText, url: shareURL),
                    fallback: LeaderboardShare.telegramURL(text: messageText, url: shareURL)
                )
            }
        case .copyLink:
            LeaderboardShareTile(
                kind: .copyLink,
                label: copied ? "Copied" : kind.title,
                isBusy: false,
                badge: copied ? "checkmark.circle.fill" : nil
            ) {
                UIPasteboard.general.string = (shareURL?.absoluteString ?? messageText)
                HapticFeedback.success.trigger()
                copied = true
            }
        case .more:
            LeaderboardShareTile(kind: .more, isBusy: false) {
                LeaderboardShare.presentSystemShareSheet(text: messageText, url: shareURL)
            }
        case .guildDM, .messages, .qrCode:
            EmptyView()
        }
    }

    private var standingsPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(window.caption.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundColor(AppColors.guildReputationAccent)
            Text(headline)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(members.prefix(3).enumerated()), id: \.element.userId) { index, member in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AppColors.greyText)
                        .frame(width: 16)
                    Text(member.displayName.isEmpty ? member.username : member.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int((member.accuracyRate * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.whiteText)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.insetPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
    }

    /// Said plainly rather than silently degrading: a link nobody outside the
    /// guild can open is a bad thing to paste into a public channel.
    private var privateStandingsNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .font(.caption)
                .foregroundColor(AppColors.statusWarning)
            Text("Your standings aren't published, so a shared link opens the guild rather than the leaderboard. Turn on Public Leaderboard in guild settings to share the standings themselves.")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    private func postToDiscord() async {
        guard let channelId = selectedChannelId, busyChannel == nil else { return }
        busyChannel = .discord
        defer { busyChannel = nil }
        do {
            _ = try await rlAppState.realApi.shareGuildLeaderboardToDiscord(
                guildId: guildId,
                channelId: channelId,
                window: window
            )
            postedLabel = usableChannels.first { $0.id == channelId }?.displayLabel
            HapticFeedback.success.trigger()
            showDiscordDestination = false
        } catch {
            rlAppState.showError(error, title: "Couldn't post standings", style: .toast)
        }
    }
}
