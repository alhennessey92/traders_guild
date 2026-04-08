//
//  InviteMembersView.swift
//  traders_guild
//
//  Admin Panel - Invite Members View
//  Search users and send guild invitations, manage pending invites
//

import SwiftUI

struct InviteMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    @State private var searchText: String = ""
    @State private var searchResults: [RLUserSearchResultDTO] = []
    @State private var pendingInvites: [RLGuildInvitationDTO] = []
    @State private var isSearching: Bool = false
    @State private var isLoadingInvites: Bool = false
    @State private var sendingInviteFor: UUID? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                AdminSheetHeader(
                    icon: "person.badge.plus",
                    iconColor: .blue,
                    title: "Invite Members",
                    subtitle: "Search and invite users to your guild"
                )
                .padding(.horizontal)
                .padding(.top, 30)

                // Search Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Users")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                        .padding(.horizontal)

                    ZStack(alignment: .trailing) {
                        UnifiedSearchBar(
                            text: $searchText,
                            placeholder: "Search by username..."
                        )
                        .padding(.horizontal)

                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.trailing, 26)
                        }
                    }
                }
                .padding(.bottom, 12)
                .adminSheetChrome(edge: .top)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Search Results
                        if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(searchText.isEmpty ? "Recommended" : "Results")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                ForEach(searchResults) { user in
                                    searchResultRow(user: user)
                                }
                            }
                        } else if !isSearching {
                            Text(searchText.isEmpty ? "No recommendations available right now" : "No users found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }

                        // Pending Invites Section
                        if !pendingInvites.isEmpty {
                            Divider()
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pending Invites (\(pendingInvites.count))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                ForEach(pendingInvites) { invite in
                                    pendingInviteRow(invite: invite)
                                }
                            }
                        } else if pendingInvites.isEmpty && !isLoadingInvites {
                            VStack(spacing: 8) {
                                Image(systemName: "envelope.badge.person.crop")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("No pending invites")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }

                        if isLoadingInvites {
                            ProgressView("Loading invites...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }

            // Dismiss button
            SheetCloseButton(action: { dismiss() })
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AdminSheetBackground())
        .onChange(of: searchText) { _, newValue in
            debounceSearch(query: newValue)
        }
        .onAppear {
            loadPendingInvites()
            Task { await performSearch(query: "") }
        }
    }

    // MARK: - Search Result Row

    @ViewBuilder
    private func searchResultRow(user: RLUserSearchResultDTO) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 40)
                .overlay(
                    Group {
                        if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let guildName = user.guildName, !guildName.isEmpty {
                    Text(user.guildRole.map { "\(guildName) • \($0.capitalized)" } ?? guildName)
                        .font(.caption2)
                        .foregroundColor(AppColors.accentColor)
                }
            }

            Spacer()

            // Action Button
            if user.isMember {
                Text("Member")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            } else if user.hasPendingInvite {
                Text("Invited")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.statusWarning10)
                    .cornerRadius(6)
            } else {
                Button(action: { sendInvite(to: user) }) {
                    HStack(spacing: 4) {
                        if sendingInviteFor == user.userId {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        Text("Invite")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(sendingInviteFor == user.userId)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Pending Invite Row

    @ViewBuilder
    private func pendingInviteRow(invite: RLGuildInvitationDTO) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 36)
                .overlay(
                    Group {
                        if let avatarUrl = invite.invitedAvatarUrl, let url = URL(string: avatarUrl) {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.invitedDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("@\(invite.invitedUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Cancel Button
            Button(action: { cancelInvite(invite) }) {
                Text("Cancel")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func debounceSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true
        do {
            searchResults = try await rlAppState.searchUsersForInvite(search: query)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    private func sendInvite(to user: RLUserSearchResultDTO) {
        sendingInviteFor = user.userId
        Task {
            do {
                let invitation = try await rlAppState.sendGuildInvite(username: user.username)
                // Update search results to show "Invited"
                if let index = searchResults.firstIndex(where: { $0.userId == user.userId }) {
                    searchResults[index] = RLUserSearchResultDTO(
                        userId: user.userId,
                        username: user.username,
                        displayName: user.displayName,
                        avatarUrl: user.avatarUrl,
                        isMember: user.isMember,
                        hasPendingInvite: true,
                        guildId: user.guildId,
                        guildName: user.guildName,
                        guildRole: user.guildRole
                    )
                }
                // Add to pending invites
                pendingInvites.insert(invitation, at: 0)
            } catch {
                // Error shown by appState
            }
            sendingInviteFor = nil
        }
    }

    private func cancelInvite(_ invite: RLGuildInvitationDTO) {
        Task {
            do {
                try await rlAppState.cancelGuildInvite(inviteId: invite.id)
                pendingInvites.removeAll { $0.id == invite.id }
                // Also update search results if applicable
                if let index = searchResults.firstIndex(where: { $0.userId == invite.invitedUserId }) {
                    let user = searchResults[index]
                    searchResults[index] = RLUserSearchResultDTO(
                        userId: user.userId,
                        username: user.username,
                        displayName: user.displayName,
                        avatarUrl: user.avatarUrl,
                        isMember: user.isMember,
                        hasPendingInvite: false,
                        guildId: user.guildId,
                        guildName: user.guildName,
                        guildRole: user.guildRole
                    )
                }
            } catch {
                // Error shown by appState
            }
        }
    }

    private func loadPendingInvites() {
        isLoadingInvites = true
        Task {
            do {
                pendingInvites = try await rlAppState.fetchGuildInvites()
            } catch {
                // Error shown by appState
            }
            isLoadingInvites = false
        }
    }
}
