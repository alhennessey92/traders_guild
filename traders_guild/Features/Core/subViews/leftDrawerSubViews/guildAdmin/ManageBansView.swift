//
//  ManageBansView.swift
//  traders_guild
//
//  Admin Panel - Manage Bans View
//  View and manage banned guild members
//

import SwiftUI

struct ManageBansView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    @State private var bans: [RLGuildBanDTO] = []
    @State private var isLoading: Bool = true
    @State private var unbanningId: UUID? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    UnifiedIconBadge(
                        icon: "person.badge.minus",
                        color: .red,
                        size: 44,
                        iconSize: 20,
                        backgroundOpacity: 0.2
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage Bans")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("View and manage banned users")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 30)

                Divider()

                // Content
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading bans...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if bans.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green.opacity(0.6))
                        Text("No Banned Users")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("There are no banned users in this guild")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(bans) { ban in
                                banRow(ban: ban)
                                if ban.id != bans.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }

            // Dismiss button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
        .onAppear {
            loadBans()
        }
    }

    // MARK: - Ban Row

    @ViewBuilder
    private func banRow(ban: RLGuildBanDTO) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 44, height: 44)
                .overlay(
                    Group {
                        if let avatarUrl = ban.bannedAvatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                )
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(ban.bannedDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("@\(ban.bannedUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let reason = ban.reason, !reason.isEmpty {
                    Text("Reason: \(reason)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Text("Banned \(ban.bannedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            // Unban Button
            Button(action: { unbanUser(ban) }) {
                HStack(spacing: 4) {
                    if unbanningId == ban.id {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text("Unban")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.green)
            .disabled(unbanningId == ban.id)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func loadBans() {
        isLoading = true
        Task {
            do {
                bans = try await rlAppState.fetchGuildBans()
            } catch {
                // Error shown by appState
            }
            isLoading = false
        }
    }

    private func unbanUser(_ ban: RLGuildBanDTO) {
        unbanningId = ban.id
        Task {
            do {
                try await rlAppState.unbanMember(banId: ban.id)
                bans.removeAll { $0.id == ban.id }
            } catch {
                // Error shown by appState
            }
            unbanningId = nil
        }
    }
}
