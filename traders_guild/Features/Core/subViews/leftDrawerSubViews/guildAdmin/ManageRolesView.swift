//
//  ManageRolesView.swift
//  traders_guild
//
//  Admin Panel - Manage Roles View
//  View members and change their roles, kick or ban
//

import SwiftUI

struct ManageRolesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    @State private var members: [RLGuildMemberDTO] = []
    @State private var isLoading: Bool = true
    @State private var selectedMember: RLGuildMemberDTO? = nil
    @State private var showRolePicker: Bool = false
    @State private var showBanAlert: Bool = false
    @State private var showKickAlert: Bool = false
    @State private var banReason: String = ""
    @State private var processingUserId: UUID? = nil

    private var isOwner: Bool {
        rlAppState.isGuildOwner
    }

    private var currentUserRole: String {
        rlAppState.currentMembership?.role ?? "member"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                AdminSheetHeader(
                    icon: "person.badge.shield.checkmark",
                    iconColor: .orange,
                    title: "Manage Roles",
                    subtitle: "Change member roles, kick or ban"
                )
                .padding(.horizontal)
                .padding(.top, 30)
                .padding(.bottom, 12)
                .adminSheetChrome(edge: .top)

                // Content
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading members...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if members.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("No Members")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(sortedMembers) { member in
                                memberRow(member: member)
                                if member.id != sortedMembers.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }

            // Dismiss button
            SheetCloseButton(action: { dismiss() })
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AdminSheetBackground())
        .onAppear {
            loadMembers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberRoleChanged)) { notification in
            guard let userInfo = notification.userInfo,
                  let userId = userInfo["userId"] as? UUID,
                  let newRole = userInfo["newRole"] as? String else { return }
            if let index = members.firstIndex(where: { $0.userId == userId }) {
                members[index] = members[index].withRole(newRole)
            }
        }
        .confirmationDialog("Change Role", isPresented: $showRolePicker, presenting: selectedMember) { member in
            rolePickerButtons(for: member)
        } message: { member in
            Text("Select a new role for \(member.username)")
        }
        .alert("Ban Member", isPresented: $showBanAlert, presenting: selectedMember) { member in
            TextField("Reason (optional)", text: $banReason)
            Button("Ban", role: .destructive) {
                banMember(member)
            }
            Button("Cancel", role: .cancel) {
                banReason = ""
            }
        } message: { member in
            Text("Are you sure you want to ban \(member.username)? They will be removed from the guild and unable to rejoin until unbanned.")
        }
        .alert("Kick Member", isPresented: $showKickAlert, presenting: selectedMember) { member in
            Button("Kick", role: .destructive) {
                kickMember(member)
            }
            Button("Cancel", role: .cancel) { }
        } message: { member in
            Text("Are you sure you want to kick \(member.username)? They will be removed from the guild but can rejoin later.")
        }
    }

    // MARK: - Sorted Members

    private var sortedMembers: [RLGuildMemberDTO] {
        members.sorted { m1, m2 in
            rolePriority(m1.role) > rolePriority(m2.role)
        }
    }

    private func rolePriority(_ role: String) -> Int {
        switch role.lowercased() {
        case "owner": return 4
        case "admin": return 3
        case "moderator": return 2
        default: return 1
        }
    }

    // MARK: - Member Row

    @ViewBuilder
    private func memberRow(member: RLGuildMemberDTO) -> some View {
        let memberRole = RLMemberRole(from: member.role)
        let isCurrentUser = member.userId == rlAppState.currentUser?.id
        let isMemberOwner = member.role.lowercased() == "owner"
        let canManageThisMember = !isCurrentUser && !isMemberOwner &&
            rolePriority(currentUserRole) > rolePriority(member.role)

        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 44, height: 44)
                .overlay(
                    Group {
                        if let avatarUrl = member.avatarUrl, let url = URL(string: avatarUrl) {
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
                HStack(spacing: 6) {
                    Text(member.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Role Badge
            HStack(spacing: 4) {
                Image(systemName: memberRole.icon)
                    .font(.caption2)
                Text(isMemberOwner ? "Owner" : memberRole.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isMemberOwner ? AppColors.memberRoleColor(.owner) : memberRole.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (isMemberOwner ? AppColors.memberRoleColor(.owner) : memberRole.color).opacity(0.1)
            )
            .cornerRadius(6)

            // Action Menu
            if canManageThisMember {
                Menu {
                    Button(action: {
                        selectedMember = member
                        showRolePicker = true
                    }) {
                        Label("Change Role", systemImage: "arrow.up.arrow.down")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        selectedMember = member
                        showKickAlert = true
                    }) {
                        Label("Kick", systemImage: "person.badge.minus")
                    }

                    Button(role: .destructive, action: {
                        selectedMember = member
                        banReason = ""
                        showBanAlert = true
                    }) {
                        Label("Ban", systemImage: "nosign")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                if processingUserId == member.userId {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Role Picker Buttons

    @ViewBuilder
    private func rolePickerButtons(for member: RLGuildMemberDTO) -> some View {
        let currentRole = member.role.lowercased()

        if currentRole != "member" {
            Button("Member") {
                changeRole(member, to: "member")
            }
        }
        if currentRole != "moderator" {
            Button("Moderator") {
                changeRole(member, to: "moderator")
            }
        }
        if currentRole != "admin" && isOwner {
            Button("Admin") {
                changeRole(member, to: "admin")
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    // MARK: - Actions

    private func loadMembers() {
        isLoading = true
        Task {
            do {
                guard let guild = rlAppState.currentGuild else { return }
                let result = try await rlAppState.fetchGuildMembers(guildId: guild.id)
                members = result.members
            } catch {
                // Error shown by appState
            }
            isLoading = false
        }
    }

    private func changeRole(_ member: RLGuildMemberDTO, to newRole: String) {
        processingUserId = member.userId
        Task {
            do {
                _ = try await rlAppState.changeMemberRole(userId: member.userId, role: newRole)
                // Update local state immediately
                if let index = members.firstIndex(where: { $0.userId == member.userId }) {
                    members[index] = members[index].withRole(newRole)
                }
            } catch {
                // Error shown by appState
            }
            processingUserId = nil
        }
    }

    private func kickMember(_ member: RLGuildMemberDTO) {
        processingUserId = member.userId
        Task {
            do {
                try await rlAppState.kickMember(userId: member.userId)
                members.removeAll { $0.userId == member.userId }
            } catch {
                // Error shown by appState
            }
            processingUserId = nil
        }
    }

    private func banMember(_ member: RLGuildMemberDTO) {
        processingUserId = member.userId
        Task {
            do {
                _ = try await rlAppState.banMember(
                    userId: member.userId,
                    reason: banReason.isEmpty ? nil : banReason
                )
                members.removeAll { $0.userId == member.userId }
                banReason = ""
            } catch {
                // Error shown by appState
            }
            processingUserId = nil
        }
    }
}
