//
//  DeleteGuildConfirmationView.swift
//  traders_guild
//
//  Type-to-confirm for owner-initiated guild deletion.
//

import SwiftUI

/// Confirms deleting a guild, and spells out what it costs.
///
/// Type-to-confirm rather than a two-button alert, mirroring
/// `DeleteAccountConfirmationView`. There is no password step: the account is
/// already authenticated and only its owner can reach this, so the friction
/// that matters is making sure the right *guild* is being deleted — hence
/// typing its name rather than a fixed phrase.
struct DeleteGuildConfirmationView: View {
    @EnvironmentObject var rlAppState: RLAppState
    @Environment(\.dismiss) private var dismiss

    let guild: RLGuildDTO
    /// Called after a successful delete, so the settings sheet behind this one
    /// can close too — it is editing a guild that no longer exists.
    let onDeleted: () -> Void

    @State private var confirmationText = ""
    @State private var isDeleting = false

    private var canDelete: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(guild.name) == .orderedSame
    }

    private let consequences: [(icon: String, text: String)] = [
        ("magnifyingglass", "It disappears from guild search, invites and every link already shared."),
        ("person.2.fill", "Members are moved to another guild of theirs, or the starter guild."),
        ("link", "Its /g/ link and its name are released — someone else can take them."),
        ("chart.line.uptrend.xyaxis", "Markers, chat and announcements stop being reachable."),
    ]

    var body: some View {
        ZStack {
            AppColors.sheetBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundColor(AppColors.statusNegative80)
                            Text("Delete \(guild.name)?")
                                .font(.title2.weight(.bold))
                                .foregroundColor(AppColors.whiteText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("This cannot be undone from the app.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(consequences, id: \.text) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.statusNegative80)
                                        .frame(width: 22)
                                    Text(item.text)
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.statusNegative80.opacity(0.08))
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type the guild's name to confirm")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.whiteText)
                            TextField(guild.name, text: $confirmationText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundColor(AppColors.whiteText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack(spacing: 10) {
                    Button {
                        Task { await deleteGuild() }
                    } label: {
                        Group {
                            if isDeleting {
                                ProgressView().tint(AppColors.onAccentForeground)
                            } else {
                                Text("Delete guild").font(.headline)
                            }
                        }
                        .foregroundColor(AppColors.onAccentForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.statusNegative80)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDelete || isDeleting)
                    .opacity(canDelete && !isDeleting ? 1 : 0.5)

                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func deleteGuild() async {
        guard canDelete, !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            _ = try await rlAppState.realApi.deleteGuild(guildId: guild.id)

            // The server has already moved everyone off it, so re-reading the
            // memberships is what tells this client where it now stands. The
            // deleted guild is filtered out server-side, so it cannot come back.
            try? await rlAppState.fetchUserGuilds()
            // Shared with the `guild_deleted` WebSocket path, and it handles the
            // case this used to miss: deleting your *only* guild left
            // `currentGuild` pointing at a guild the server now refuses.
            await rlAppState.moveOffDeletedGuild(deletedGuild: guild)

            // Close first, confirm after. The relocation above raises the
            // transition, and a toast fired now is announcing a result behind a
            // cover that is still saying "Deleting" — so it is held until the
            // user is actually looking at the guild they have been moved to.
            dismiss()
            onDeleted()
            rlAppState.confirmAfterTransition(
                "\(guild.name) has been deleted.",
                title: "Guild Deleted"
            )
        } catch {
            rlAppState.showError(
                error,
                title: "Couldn't Delete Guild",
                style: .toast
            )
        }
    }
}
