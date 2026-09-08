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

extension Notification.Name {
    /// Posted once the create-a-guild flow is completely off screen — the
    /// invite hub included. The drawer closes its own sheet stack on it, and
    /// MainView waits a beat before asking about Discord.
    static let guildCreationDidFinish = Notification.Name("guildCreationDidFinish")
}

/// userInfo key carrying the new guild's `UUID` on `.guildCreationDidFinish`.
enum GuildCreationNotification {
    static let guildIdKey = "guildId"
}

@MainActor
enum DiscordSetupReminder {
    /// The beat between closing the celebration and asking about Discord.
    ///
    /// This was ten seconds, on the reasoning that the owner was still reading
    /// the invite hub — and they were, because the prompt was queued while the
    /// hub was still open. The hub is now dismissed before this runs, so ten
    /// seconds is just the owner sitting on a chart wondering whether anything
    /// else was going to happen. Long enough for the cover to finish leaving,
    /// and no longer.
    static let postCreationDelay: Duration = .milliseconds(350)

    /// Guilds whose creation flow is still on screen.
    ///
    /// Creating a guild makes it current, which trips the same `task(id:)` that
    /// drives the reminder — so the prompt tried to present itself on top of the
    /// invite hub's full-screen cover. UIKit renders that sheet but never puts
    /// it in the window hierarchy, so it appears with every control dead.
    /// Held with the time it was taken, because a deferral is a courtesy and
    /// not a lock: if the end of the create flow is ever missed, the prompt has
    /// to come round again rather than be stranded for the life of the process.
    private static var guildsBeingCreated: [UUID: Date] = [:]
    private static let creationDeferralLifetime: TimeInterval = 60

    static func deferWhileCreating(guildId: UUID, now: Date = Date()) {
        guildsBeingCreated[guildId] = now
    }

    static func endCreationDeferral(guildId: UUID) {
        guildsBeingCreated.removeValue(forKey: guildId)
    }

    static func isDeferredForCreation(guildId: UUID, now: Date = Date()) -> Bool {
        guard let deferredAt = guildsBeingCreated[guildId] else { return false }
        guard now.timeIntervalSince(deferredAt) < creationDeferralLifetime else {
            guildsBeingCreated.removeValue(forKey: guildId)
            return false
        }
        return true
    }

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
///
/// Built around the guild rather than around Discord. The ask is "put *your*
/// community's results in *your* channel", and a sheet that opened on a generic
/// logo and three bullet points read as an integration to configure rather than
/// something to want. So the guild's own banner, crest and colour lead, and an
/// example of the post it produces sits above the benefits — the payoff is the
/// argument, and it is the one thing a list of features cannot show.
///
/// Ported from Android's `DiscordSetupReminderSheet.kt`, which the user signed
/// off on. Copy is shared verbatim with `strings.xml:876-890`; only the
/// example-post lines are new here.
struct DiscordSetupReminderSheet: View {
    /// The whole guild, not just its name: the hero and the example post are
    /// built from its banner, crest and colour.
    let guild: RLGuildDTO?
    let guildName: String
    let onConnect: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var accent: Color { GuildTheme.accent(for: guild) }

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
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    GuildSheetHeader(
                        guild: guild,
                        title: "Connect \(guildName) to Discord",
                        subtitle: "Your community doesn't have to move. Paste one webhook and Traders Guild starts posting into the channel you already use.",
                        accent: accent,
                        trailingBadge: { discordBadge }
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)

                    examplePost
                        .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.title) { benefit in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: benefit.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(accent)
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
                    .padding(.horizontal, 24)

                    Text("Takes about a minute: Discord → Channel Settings → Integrations → Webhooks.")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.whiteText.opacity(0.05))
                        )
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
            }

            // Pinned, not scrolled. The hero pushed "Connect a channel" below the
            // fold, and a call to action you have to scroll for on a prompt you
            // did not ask for is one nobody takes.
            footer
        }
        .background(AppColors.sheetBackground.ignoresSafeArea())
    }

    /// The Discord half of the header's paired badges.
    private var discordBadge: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.16))
                .overlay(Circle().stroke(accent.opacity(0.45), lineWidth: 1))
            Image("DiscordLogo")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .foregroundColor(accent)
        }
        .frame(
            width: GuildSheetHeaderMetrics.crestSize - 4,
            height: GuildSheetHeaderMetrics.crestSize - 4
        )
    }

    /// Deliberately fictional and labelled as such: a card that looked like a
    /// live post would be worse than no card.
    private var examplePost: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXAMPLE POST")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.greyText)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        if let guild {
                            GuildCrestView(guild: guild, size: 18)
                        }
                        Text(guildName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.greyText)
                    }
                    Text("EURUSD · Long · 1H")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.whiteText)
                    Text("Target hit · +1.8R")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.statusPositive)
                    Text("@trader · 62% tracked accuracy · #3 in \(guildName)")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.greyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Spacer(minLength: 0)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.whiteText.opacity(0.055))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.whiteText.opacity(0.09), lineWidth: 1)
            )
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                dismiss()
                onConnect()
            } label: {
                HStack(spacing: 8) {
                    Image("DiscordLogo")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 21, height: 21)
                    Text("Connect a channel")
                        .font(.headline)
                }
                .foregroundColor(AppColors.onAccentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 26).fill(accent))
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
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AppColors.sheetBackground)
    }
}
