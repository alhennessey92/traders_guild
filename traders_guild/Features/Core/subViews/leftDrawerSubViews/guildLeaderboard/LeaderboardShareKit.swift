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

    static func telegramURL(text: String, url: URL?) -> URL? {
        var components = URLComponents(string: "https://t.me/share/url")
        var items = [URLQueryItem(name: "text", value: text)]
        // Telegram wants the link in `url`; without one it still posts the text.
        if let url {
            items.insert(URLQueryItem(name: "url", value: url.absoluteString), at: 0)
        }
        components?.queryItems = items
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
    static func personalMessage(
        guildName: String,
        window: LeaderboardWindow,
        profile: RLAccuracyProfileDTO,
        rank: Int?,
        url: URL?
    ) -> String {
        let accuracy = Int((profile.accuracyRate * 100).rounded())
        let losses = max(0, profile.totalPredictions - profile.successfulPredictions)
        var line = "\(accuracy)% accuracy on \(profile.totalPredictions) tracked setups "
            + "(\(profile.successfulPredictions)W · \(losses)L) in \(guildName)."
        if let rank {
            line += " Ranked #\(rank)."
        }
        var parts = [line]
        parts.append("Every call is scored automatically when it hits its target or stop — no cherry-picking.")
        if let url {
            parts.append(url.absoluteString)
        }
        return parts.joined(separator: "\n\n")
    }
}

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
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(messageText)
                        .font(.subheadline)
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

                    VStack(alignment: .leading, spacing: 10) {
                        row("Post on X", icon: "arrow.up.forward.app") {
                            open(LeaderboardShare.xComposeURL(text: messageText))
                        }
                        row("Send on Telegram", icon: "paperplane.fill") {
                            open(LeaderboardShare.telegramURL(text: messageText, url: shareURL))
                        }
                        row("Copy", icon: "doc.on.doc") {
                            UIPasteboard.general.string = messageText
                            HapticFeedback.light.trigger()
                        }
                        row("More…", icon: "square.and.arrow.up") {
                            LeaderboardShare.presentSystemShareSheet(
                                text: messageText, url: shareURL
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(AppColors.sheetBackground.ignoresSafeArea())
            .navigationTitle("Share your record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.guildReputationAccent)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.insetPanelBackground))
        }
        .buttonStyle(.plain)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
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
    @State private var isPosting = false
    @State private var postedLabel: String?

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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    preview

                    if !isPublished {
                        privateStandingsNote
                    }

                    if !usableChannels.isEmpty {
                        discordSection
                    }

                    elsewhereSection
                }
                .padding(20)
            }
            .background(AppColors.sheetBackground.ignoresSafeArea())
            .navigationTitle("Share standings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            selectedChannelId = (usableChannels.first(where: \.isDefault) ?? usableChannels.first)?.id
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(window.caption.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundColor(AppColors.guildReputationAccent)
            Text(LeaderboardShare.headline(guildName: guildName, window: window, leader: leader))
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

    private var discordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Post to Discord")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.greyText)

            if usableChannels.count > 1 {
                Picker("Channel", selection: $selectedChannelId) {
                    ForEach(usableChannels) { channel in
                        Text(channel.displayLabel).tag(Optional(channel.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.whiteText)
            }

            Button {
                Task { await postToDiscord() }
            } label: {
                Group {
                    if isPosting {
                        ProgressView().tint(AppColors.onAccentForeground)
                    } else if let postedLabel {
                        Label("Posted to \(postedLabel)", systemImage: "checkmark")
                            .font(.headline)
                    } else {
                        Text(selectedLabel.map { "Post to \($0)" } ?? "Choose a channel")
                            .font(.headline)
                    }
                }
                .foregroundColor(AppColors.onAccentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedChannelId == nil ? AppColors.surfaceWhite12 : AppColors.tgAccent)
                )
            }
            .disabled(isPosting || selectedChannelId == nil || postedLabel != nil)
        }
    }

    private var selectedLabel: String? {
        usableChannels.first { $0.id == selectedChannelId }?.displayLabel
    }

    private var elsewhereSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share elsewhere")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.greyText)

            shareRow("Post on X", icon: "arrow.up.forward.app") {
                open(LeaderboardShare.xComposeURL(text: messageText))
            }
            shareRow("Send on Telegram", icon: "paperplane.fill") {
                open(LeaderboardShare.telegramURL(text: messageText, url: shareURL))
            }
            if let shareURL {
                shareRow("Copy link", icon: "doc.on.doc") {
                    UIPasteboard.general.string = shareURL.absoluteString
                    HapticFeedback.light.trigger()
                }
            }
            shareRow("More…", icon: "square.and.arrow.up") {
                LeaderboardShare.presentSystemShareSheet(text: messageText, url: shareURL)
            }
        }
    }

    private func shareRow(
        _ title: String, icon: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.guildReputationAccent)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.insetPanelBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    private func postToDiscord() async {
        guard let channelId = selectedChannelId, !isPosting else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            _ = try await rlAppState.realApi.shareGuildLeaderboardToDiscord(
                guildId: guildId,
                channelId: channelId,
                window: window
            )
            postedLabel = selectedLabel
            HapticFeedback.success.trigger()
        } catch {
            rlAppState.showError(error, title: "Couldn't post standings", style: .toast)
        }
    }
}
