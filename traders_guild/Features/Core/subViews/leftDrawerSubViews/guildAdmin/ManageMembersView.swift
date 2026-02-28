//
//  ManageMembersView.swift
//  traders_guild
//
//  Admin/Moderator Panel - Manage Members View
//  Tabbed view: Active members, Muted, Suspended, Banned
//  Replaces ManageBansView with full member management
//

import SwiftUI

struct ManageMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    enum MemberTab: String, CaseIterable {
        case active = "Active"
        case muted = "Muted"
        case suspended = "Suspended"
        case banned = "Banned"

        var icon: String {
            switch self {
            case .active: return "person.2.fill"
            case .muted: return "speaker.slash.fill"
            case .suspended: return "pause.circle.fill"
            case .banned: return "nosign"
            }
        }
    }

    @State private var selectedTab: MemberTab = .active
    @State private var members: [RLGuildMemberDTO] = []
    @State private var bans: [RLGuildBanDTO] = []
    @State private var isLoading: Bool = true
    @State private var processingUserId: UUID? = nil
    @State private var unbanningId: UUID? = nil

    // Action sheets
    @State private var selectedMember: RLGuildMemberDTO? = nil
    @State private var showMuteSheet: Bool = false
    @State private var showSuspendSheet: Bool = false
    @State private var showKickAlert: Bool = false
    @State private var showBanAlert: Bool = false
    @State private var actionReason: String = ""
    @State private var selectedDuration: Int = 60  // minutes

    private var isOwner: Bool {
        rlAppState.isGuildOwner
    }

    private var currentUserRole: String {
        rlAppState.currentMembership?.role ?? "member"
    }

    private var canAdmin: Bool {
        rlAppState.canAdmin
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal)
                    .padding(.top, 30)

                Divider()
                    .padding(.top, 12)

                // Tab Bar
                tabBar
                    .padding(.top, 8)

                Divider()

                // Content
                contentView
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
        .background(AdminSheetBackground())
        .onAppear {
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberMuteChanged)) { notification in
            handleMuteNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberSuspendChanged)) { notification in
            handleSuspendNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberRoleChanged)) { notification in
            guard let userInfo = notification.userInfo,
                  let userId = userInfo["userId"] as? UUID,
                  let newRole = userInfo["newRole"] as? String else { return }
            if let index = members.firstIndex(where: { $0.userId == userId }) {
                members[index] = members[index].withRole(newRole)
            }
        }
        // Mute confirmation
        .confirmationDialog("Mute Member", isPresented: $showMuteSheet, presenting: selectedMember) { member in
            muteConfirmationButtons(for: member)
        } message: { member in
            Text("Select mute duration for \(member.username)")
        }
        // Suspend confirmation
        .confirmationDialog("Suspend Member", isPresented: $showSuspendSheet, presenting: selectedMember) { member in
            suspendConfirmationButtons(for: member)
        } message: { member in
            Text("Select suspension duration for \(member.username). They will not be able to interact at all.")
        }
        // Kick alert
        .alert("Kick Member", isPresented: $showKickAlert, presenting: selectedMember) { member in
            Button("Kick", role: .destructive) {
                kickMember(member)
            }
            Button("Cancel", role: .cancel) { }
        } message: { member in
            Text("Are you sure you want to kick \(member.username)? They will be removed from the guild but can rejoin later.")
        }
        // Ban alert
        .alert("Ban Member", isPresented: $showBanAlert, presenting: selectedMember) { member in
            TextField("Reason (optional)", text: $actionReason)
            Button("Ban", role: .destructive) {
                banMember(member)
            }
            Button("Cancel", role: .cancel) {
                actionReason = ""
            }
        } message: { member in
            Text("Are you sure you want to ban \(member.username)? They will be removed and unable to rejoin until unbanned.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        AdminSheetHeader(
            icon: "person.2.fill",
            iconColor: .purple,
            title: "Manage Members",
            subtitle: "Moderate guild membership"
        )
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(MemberTab.allCases, id: \.self) { tab in
                // Hide banned tab for moderators (admin+ only)
                if tab != .banned || canAdmin {
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.caption2)
                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                            // Badge count
                            let count = badgeCount(for: tab)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(tab == .banned ? .red : .orange))
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            switch selectedTab {
            case .active:
                activeMembersList
            case .muted:
                mutedMembersList
            case .suspended:
                suspendedMembersList
            case .banned:
                bannedList
            }
        }
    }

    // MARK: - Active Members List

    private var activeMembersList: some View {
        let activeMembers = members.filter { !$0.isMuted && !$0.isSuspended }
        return Group {
            if activeMembers.isEmpty {
                emptyState(icon: "person.3.fill", title: "No Active Members", subtitle: "No members to display")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sortedMembers(activeMembers)) { member in
                            memberRow(member: member)
                            if member.id != sortedMembers(activeMembers).last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Muted Members List

    private var mutedMembersList: some View {
        let mutedMembers = members.filter { $0.isMuted }
        return Group {
            if mutedMembers.isEmpty {
                emptyState(icon: "speaker.fill", title: "No Muted Members", subtitle: "No members are currently muted")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(mutedMembers) { member in
                            mutedMemberRow(member: member)
                            if member.id != mutedMembers.last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Suspended Members List

    private var suspendedMembersList: some View {
        let suspendedMembers = members.filter { $0.isSuspended }
        return Group {
            if suspendedMembers.isEmpty {
                emptyState(icon: "play.circle.fill", title: "No Suspended Members", subtitle: "No members are currently suspended")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(suspendedMembers) { member in
                            suspendedMemberRow(member: member)
                            if member.id != suspendedMembers.last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Banned List

    private var bannedList: some View {
        Group {
            if bans.isEmpty {
                emptyState(icon: "checkmark.shield.fill", title: "No Banned Users", subtitle: "There are no banned users in this guild")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(bans) { ban in
                            banRow(ban: ban)
                            if ban.id != bans.last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Member Row (Active)

    @ViewBuilder
    private func memberRow(member: RLGuildMemberDTO) -> some View {
        let memberRole = RLMemberRole(from: member.role)
        let isCurrentUser = member.userId == rlAppState.currentUser?.id
        let isMemberOwner = member.role.lowercased() == "owner"
        let canManageThisMember = !isCurrentUser && !isMemberOwner &&
            rolePriority(currentUserRole) > rolePriority(member.role)

        HStack(spacing: 12) {
            // Avatar
            memberAvatar(avatarUrl: member.avatarUrl)

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
            roleBadge(role: memberRole, isOwner: isMemberOwner)

            // Action Menu
            if canManageThisMember {
                Menu {
                    // Mute - available to Moderator+
                    Button(action: {
                        selectedMember = member
                        showMuteSheet = true
                    }) {
                        Label("Mute", systemImage: "speaker.slash.fill")
                    }

                    // Suspend - available to Moderator+
                    Button(action: {
                        selectedMember = member
                        showSuspendSheet = true
                    }) {
                        Label("Suspend", systemImage: "pause.circle.fill")
                    }

                    // Kick & Ban - Admin+ only
                    if canAdmin {
                        Divider()

                        Button(role: .destructive, action: {
                            selectedMember = member
                            showKickAlert = true
                        }) {
                            Label("Kick", systemImage: "person.badge.minus")
                        }

                        Button(role: .destructive, action: {
                            selectedMember = member
                            actionReason = ""
                            showBanAlert = true
                        }) {
                            Label("Ban", systemImage: "nosign")
                        }
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

    // MARK: - Muted Member Row

    @ViewBuilder
    private func mutedMemberRow(member: RLGuildMemberDTO) -> some View {
        HStack(spacing: 12) {
            memberAvatar(avatarUrl: member.avatarUrl)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let mutedUntil = member.mutedUntil {
                    Text("Expires \(mutedUntil, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Unmute button
            Button(action: { unmuteMember(member) }) {
                HStack(spacing: 4) {
                    if processingUserId == member.userId {
                        ProgressView().scaleEffect(0.6)
                    }
                    Text("Unmute")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.green)
            .disabled(processingUserId == member.userId)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Suspended Member Row

    @ViewBuilder
    private func suspendedMemberRow(member: RLGuildMemberDTO) -> some View {
        HStack(spacing: 12) {
            memberAvatar(avatarUrl: member.avatarUrl)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let suspendedUntil = member.suspendedUntil {
                    Text("Expires \(suspendedUntil, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Unsuspend button
            Button(action: { unsuspendMember(member) }) {
                HStack(spacing: 4) {
                    if processingUserId == member.userId {
                        ProgressView().scaleEffect(0.6)
                    }
                    Text("Unsuspend")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.green)
            .disabled(processingUserId == member.userId)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Ban Row

    @ViewBuilder
    private func banRow(ban: RLGuildBanDTO) -> some View {
        HStack(spacing: 12) {
            memberAvatar(avatarUrl: ban.bannedAvatarUrl)

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
                        ProgressView().scaleEffect(0.6)
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

    // MARK: - Shared Components

    private func memberAvatar(avatarUrl: String?) -> some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 44, height: 44)
            .overlay(
                Group {
                    if let avatarUrl = avatarUrl, let url = URL(string: avatarUrl) {
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
    }

    private func roleBadge(role: RLMemberRole, isOwner: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: role.icon)
                .font(.caption2)
            Text(isOwner ? "Owner" : role.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(isOwner ? .yellow : role.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (isOwner ? Color.yellow : role.color).opacity(0.1)
        )
        .cornerRadius(6)
    }

    // MARK: - Confirmation Buttons

    @ViewBuilder
    private func muteConfirmationButtons(for member: RLGuildMemberDTO) -> some View {
        Button("15 minutes") { performMute(member, minutes: 15) }
        Button("1 hour") { performMute(member, minutes: 60) }
        Button("6 hours") { performMute(member, minutes: 360) }
        Button("24 hours") { performMute(member, minutes: 1440) }
        Button("7 days") { performMute(member, minutes: 10080) }
        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private func suspendConfirmationButtons(for member: RLGuildMemberDTO) -> some View {
        Button("1 hour") { performSuspend(member, minutes: 60) }
        Button("6 hours") { performSuspend(member, minutes: 360) }
        Button("24 hours") { performSuspend(member, minutes: 1440) }
        Button("7 days") { performSuspend(member, minutes: 10080) }
        Button("30 days") { performSuspend(member, minutes: 43200) }
        Button("Cancel", role: .cancel) { }
    }

    // MARK: - Helpers

    private func rolePriority(_ role: String) -> Int {
        switch role.lowercased() {
        case "owner": return 4
        case "admin": return 3
        case "moderator": return 2
        default: return 1
        }
    }

    private func sortedMembers(_ list: [RLGuildMemberDTO]) -> [RLGuildMemberDTO] {
        list.sorted { rolePriority($0.role) > rolePriority($1.role) }
    }

    private func badgeCount(for tab: MemberTab) -> Int {
        switch tab {
        case .active: return 0
        case .muted: return members.filter { $0.isMuted }.count
        case .suspended: return members.filter { $0.isSuspended }.count
        case .banned: return bans.count
        }
    }

    // MARK: - Notification Handlers

    private func handleMuteNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let userId = userInfo["userId"] as? UUID,
              let action = userInfo["action"] as? String else { return }

        if let index = members.firstIndex(where: { $0.userId == userId }) {
            // Refresh to get updated muted_until from server
            loadData()
        }
    }

    private func handleSuspendNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let userId = userInfo["userId"] as? UUID else { return }

        if let index = members.firstIndex(where: { $0.userId == userId }) {
            loadData()
        }
    }

    // MARK: - Actions

    private func loadData() {
        isLoading = true
        Task {
            do {
                guard let guild = rlAppState.currentGuild else { return }
                let result = try await rlAppState.fetchGuildMembers(guildId: guild.id)
                members = result.members

                // Only load bans for admin+
                if canAdmin {
                    bans = try await rlAppState.fetchGuildBans()
                }
            } catch {
                // Error shown by appState
            }
            isLoading = false
        }
    }

    private func performMute(_ member: RLGuildMemberDTO, minutes: Int) {
        processingUserId = member.userId
        Task {
            do {
                try await rlAppState.muteMember(userId: member.userId, durationMinutes: minutes, reason: nil)
                loadData()
            } catch {
                // Error shown by appState
            }
            processingUserId = nil
        }
    }

    private func unmuteMember(_ member: RLGuildMemberDTO) {
        processingUserId = member.userId
        Task {
            do {
                try await rlAppState.unmuteMember(userId: member.userId)
                loadData()
            } catch {
                // Error shown by appState
            }
            processingUserId = nil
        }
    }

    private func performSuspend(_ member: RLGuildMemberDTO, minutes: Int) {
        processingUserId = member.userId
        Task {
            do {
                try await rlAppState.suspendMember(userId: member.userId, durationMinutes: minutes, reason: nil)
                loadData()
            } catch {
                // Error shown by appState
            }
            processingUserId = nil
        }
    }

    private func unsuspendMember(_ member: RLGuildMemberDTO) {
        processingUserId = member.userId
        Task {
            do {
                try await rlAppState.unsuspendMember(userId: member.userId)
                loadData()
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
                let ban = try await rlAppState.banMember(userId: member.userId, reason: actionReason.isEmpty ? nil : actionReason)
                members.removeAll { $0.userId == member.userId }
                bans.insert(ban, at: 0)
                actionReason = ""
            } catch {
                // Error shown by appState
            }
            processingUserId = nil
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
