//
//  DiscordSetupReminder.swift
//  traders_guild
//
//  Reminding a guild owner that their Discord is not connected yet.
//
//  The trading layer only pays for itself once results land back in the
//  community the guild came from, and that needs one webhook an owner pastes
//  in once. It is easy to mean to do and never do — so this asks again, on a
//  cadence slow enough not to nag: after the guild is created, then monthly,
//  and once after an app update in case the reason to care has changed.
//
//  Owner only. An admin cannot be held responsible for the guild's reach, and
//  a member has nothing to act on.
//

import SwiftUI

@MainActor
enum DiscordSetupReminder {
    /// Slow enough that an owner who said "not now" is not asked again this
    /// month, frequent enough that it does not simply get forgotten.
    static let interval: TimeInterval = 30 * 24 * 60 * 60

    private static let shownAtKey = "discord.setup.remindedAt."
    private static let shownVersionKey = "discord.setup.remindedVersion."

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Whether to prompt the owner of `guildId` right now.
    ///
    /// `hasChannel` is the whole point of the reminder: once a channel exists
    /// there is nothing to remind anyone about, so it short-circuits first.
    static func shouldRemind(
        guildId: UUID,
        isOwner: Bool,
        hasChannel: Bool,
        now: Date = Date()
    ) -> Bool {
        guard isOwner, !hasChannel else { return false }

        let defaults = UserDefaults.standard
        let lastShown = defaults.object(forKey: shownAtKey + guildId.uuidString) as? Date
        guard let lastShown else {
            // Never asked — this is the just-created-a-guild case.
            return true
        }
        if now.timeIntervalSince(lastShown) >= interval { return true }
        // A new build may have changed what connecting actually gets them, so
        // it earns one more ask even inside the month.
        let lastVersion = defaults.string(forKey: shownVersionKey + guildId.uuidString)
        return lastVersion != appVersion
    }

    static func recordShown(guildId: UUID, now: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(now, forKey: shownAtKey + guildId.uuidString)
        defaults.set(appVersion, forKey: shownVersionKey + guildId.uuidString)
    }
}

/// The prompt itself — what connecting a channel actually buys the owner.
struct DiscordSetupReminderSheet: View {
    let guildName: String
    let onConnect: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, title: String, detail: String)] = [
        (
            "target",
            "Results post themselves",
            "When a tracked setup hits its target or stop, the outcome goes back to your channel — with the chart and the caller's record."
        ),
        (
            "chart.bar.fill",
            "Weekly standings",
            "One post a week showing who in your community is actually calling it best."
        ),
        (
            "arrow.up.forward.app",
            "Ideas, not scrollback",
            "Setups shared from the app arrive as a chart card instead of a wall of text."
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        Image("DiscordLogo")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .foregroundColor(AppColors.guildReputationAccent)
                        Text("Connect \(guildName) to Discord")
                            .font(.title3.weight(.bold))
                            .foregroundColor(AppColors.whiteText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Your community doesn't have to move. Paste one webhook and Traders Guild starts posting into the channel you already use.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.title) { benefit in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: benefit.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.guildReputationAccent)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(benefit.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(AppColors.whiteText)
                                    Text(benefit.detail)
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    Text("Takes about a minute: Discord → Channel Settings → Integrations → Webhooks.")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismiss()
                        onConnect()
                    } label: {
                        Text("Connect a channel")
                            .font(.headline)
                            .foregroundColor(AppColors.onAccentForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.tgAccent))
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("Not now")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
            .background(AppColors.sheetBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
