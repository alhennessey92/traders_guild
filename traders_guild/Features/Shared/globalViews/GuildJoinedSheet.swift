//
//  GuildJoinedSheet.swift
//  traders_guild
//
//  The welcome shown once, immediately after joining a guild.
//

import SwiftUI

/// Where you have landed, shown the moment you land there.
///
/// Joining produced a success toast and nothing else. On the shared-marker and
/// invite-link paths that dropped someone straight onto a stranger's chart with
/// no sense of whose it was — the toast is gone in four seconds and says only
/// that something worked. This is the arrival: who runs the place, how big it
/// is, and whatever the owner wrote to greet people.
///
/// Ported from Android's `GuildJoinedSheet.kt`, which the user signed off on;
/// the structure and copy are kept in step deliberately. Note the name there —
/// `GuildWelcomeSheet` is the *owner-authoring* sheet that writes the
/// announcement this one reads.
///
/// There is no `rules` field on the backend and the backend is frozen, so the
/// greeting is the guild's pinned-or-latest announcement. That is already the
/// product's intent: the owner's authoring sheet prompts them to "Introduce the
/// guild, set the tone, list the rules".
struct GuildJoinedSheet: View {
    let guild: RLGuildDTO
    let onDismiss: () -> Void
    let onViewGuild: () -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @State private var welcome: RLGuildAnnouncementResponseDTO?

    /// The guild's own colour, not the app's — this sheet is entirely about one
    /// guild, and `DiscordSetupReminderSheet` set the precedent.
    private var accent: Color { GuildTheme.accent(for: guild) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    body_
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)
            }

            // Pinned, like the Discord prompt's: this sheet is tall enough that
            // "Start exploring" would otherwise sit below the fold on a guild
            // with a long greeting.
            footer
        }
        .background(AppColors.sheetBackground.ignoresSafeArea())
        .task(id: guild.id) {
            // Best effort. The sheet is worth showing with or without a
            // greeting, so a failure just leaves the block out rather than
            // raising an error over a welcome.
            guard let list = try? await rlAppState.realApi.getGuildAnnouncements(guildId: guild.id)
            else { return }
            let all = list.announcements.map(\.announcement)
            welcome = all.first(where: \.isImportant) ?? all.first
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Text("You're in")
                .font(.caption.weight(.semibold))
                .foregroundColor(accent)

            GuildCrestView(guild: guild, size: 72)

            Text(guild.name)
                .font(.title2.weight(.bold))
                .foregroundColor(AppColors.whiteText)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if let slug = guild.slug, !slug.isEmpty {
                    Text("@\(slug)")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                accessBadge
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var accessBadge: some View {
        Text(guild.isOpen ? "Open" : "Invite only")
            .font(.caption2.weight(.semibold))
            .foregroundColor(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(accent.opacity(0.16))
            )
            .overlay(
                Capsule().stroke(accent.opacity(0.45), lineWidth: 1)
            )
    }

    // MARK: - Body

    // `body_` because `body` is the View requirement.
    private var body_: some View {
        VStack(spacing: 16) {
            if let description = guild.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                statTile("Members", "\(guild.memberCount)")
                statTile("Online", "\(guild.membersOnline)")
                if let year = foundedYear {
                    statTile("Since", year)
                }
            }

            ownerRow

            if let welcome {
                infoCard(title: welcome.title.isEmpty ? "Welcome" : welcome.title) {
                    Text(welcome.content.isEmpty ? (welcome.preview ?? "") : welcome.content)
                        .font(.footnote)
                        .foregroundColor(AppColors.whiteText.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(AppColors.whiteText)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.whiteText.opacity(0.05))
        )
    }

    private var ownerRow: some View {
        HStack(spacing: 12) {
            UnifiedMemberAvatar(
                username: guild.ownerDisplayName ?? guild.ownerUsername ?? "?",
                avatarURL: guild.ownerAvatarUrl,
                size: 36,
                showOnlineIndicator: false
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("Led by")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                Text(guild.ownerDisplayName ?? guild.ownerUsername ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.whiteText.opacity(0.05))
        )
    }

    private func infoCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.whiteText)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.whiteText.opacity(0.05))
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                StandardActionButtonFullWidth(
                    title: "Start exploring",
                    backgroundColor: accent,
                    foregroundColor: AppColors.whiteText
                ) {
                    onDismiss()
                }

                Button(action: onViewGuild) {
                    Text("View guild")
                        .font(.footnote)
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(AppColors.sheetBackground)
        }
    }

    private var foundedYear: String? {
        let year = Calendar.current.component(.year, from: guild.dateCreated)
        return String(year)
    }
}
