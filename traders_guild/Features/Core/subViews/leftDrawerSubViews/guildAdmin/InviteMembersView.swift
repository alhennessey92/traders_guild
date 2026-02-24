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
                HStack(spacing: 12) {
                    UnifiedIconBadge(
                        icon: "person.badge.plus",
                        color: .blue,
                        size: 44,
                        iconSize: 20,
                        backgroundOpacity: 0.2
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invite Members")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Search and invite users to your guild")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 30)

                Divider()

                // Search Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Users")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search by username...", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Search Results
                        if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Results")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                ForEach(searchResults) { user in
                                    searchResultRow(user: user)
                                }
                            }
                        } else if !searchText.isEmpty && !isSearching {
                            Text("No users found")
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
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
        .onChange(of: searchText) { _, newValue in
            debounceSearch(query: newValue)
        }
        .onAppear {
            loadPendingInvites()
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
                    .background(Color.orange.opacity(0.1))
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
        guard query.count >= 2 else {
            searchResults = []
            return
        }
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
                        hasPendingInvite: true
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
                        hasPendingInvite: false
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
