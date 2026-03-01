//
//  LeaderboardView.swift
//  traders_guild
//
//  Leaderboard View for Left Drawer
//  Remodel: Primary tabs are Guild / Global, with breakdown modes.
//  Uses UnifiedComponents for consistent styling
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - LEADERBOARD TAB DEFINITION
// MARK: - ================================================================================================

enum LeaderboardTab: String, CaseIterable, UnifiedTabItem {
    case guild = "Guild"
    case global = "Global"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .guild: return "person.3.fill"
        case .global: return "globe"
        }
    }
}

private enum GuildLeaderboardMode: String, CaseIterable, UnifiedTabItem {
    case reputation = "Reputation"
    case accuracy = "Accuracy"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .reputation: return "shield.pattern.checkered"
        case .accuracy: return "target"
        }
    }
}

private enum GlobalLeaderboardScope: String, CaseIterable, UnifiedTabItem {
    case users = "Users"
    case guilds = "Guilds"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .users: return "person.2.fill"
        case .guilds: return "building.2.fill"
        }
    }
}

private enum GlobalLeaderboardMode: String, CaseIterable, UnifiedTabItem {
    case reputation = "Reputation"
    case accuracy = "Accuracy"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .reputation: return "shield.pattern.checkered"
        case .accuracy: return "target"
        }
    }
}

private struct GlobalUserRankEntry: Identifiable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let isOnline: Bool
    let roleText: String
    let roleColor: Color
    let isBlocked: Bool
    let isFriend: Bool
    let globalReputation: Int
    let accuracyRate: Double?
    let guildMember: RLGuildMemberDTO?

    var id: UUID { userId }

    var accuracyFormatted: String {
        "\(Int((accuracyRate ?? 0) * 100))%"
    }
}

private struct GlobalGuildRankEntry: Identifiable {
    let guild: RLGuildDTO
    let averageAccuracy: Double?

    var id: UUID { guild.id }
    var name: String { guild.name }
    var memberCount: Int { guild.memberCount }
    var membersOnline: Int { guild.membersOnline }
    var reputation: Int { guild.reputation }
    var reputationFormatted: String { guild.reputationDisplay }
    var accuracyFormatted: String { String(format: "%.1f%%", (averageAccuracy ?? 0) * 100) }
}

// MARK: - ================================================================================================
// MARK: - LEADERBOARD LIST VIEW
// MARK: - ================================================================================================

struct LeaderboardListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var rlAppState: RLAppState

    @State private var selectedTab: LeaderboardTab = .guild
    @State private var selectedGuildMode: GuildLeaderboardMode = .reputation
    @State private var selectedGlobalScope: GlobalLeaderboardScope = .users
    @State private var selectedGlobalMode: GlobalLeaderboardMode = .reputation
    @State private var discoveredGuilds: [RLGuildDTO] = []
    @State private var joinedGuildAccuracy: [UUID: Double] = [:]
    @State private var isLoadingGlobalGuilds: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .blue,
                countForTab: { tab in countForPrimaryTab(tab) },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            if selectedTab == .guild {
                UnifiedTabBar(
                    selectedTab: $selectedGuildMode,
                    size: .compact,
                    theme: .amber,
                    countForTab: { tab in countForGuildMode(tab) },
                    spacing: 6
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                UnifiedTabBar(
                    selectedTab: $selectedGlobalScope,
                    size: .compact,
                    theme: .emerald,
                    countForTab: { tab in countForGlobalScope(tab) },
                    spacing: 6
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                UnifiedTabBar(
                    selectedTab: $selectedGlobalMode,
                    size: .compact,
                    theme: .magenta,
                    countForTab: { tab in countForGlobalMode(tab) },
                    spacing: 6
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    switch selectedTab {
                    case .guild:
                        switch selectedGuildMode {
                        case .reputation:
                            guildReputationContent
                        case .accuracy:
                            guildAccuracyContent
                        }
                    case .global:
                        switch selectedGlobalScope {
                        case .users:
                            switch selectedGlobalMode {
                            case .reputation:
                                globalUsersReputationContent
                            case .accuracy:
                                globalUsersAccuracyContent
                            }
                        case .guilds:
                            switch selectedGlobalMode {
                            case .reputation:
                                globalGuildsReputationContent
                            case .accuracy:
                                globalGuildsAccuracyContent
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .refreshable {
                await refreshLeaderboard()
            }
        }
        .task {
            await initialLoad()
        }
    }
}

private extension LeaderboardListView {
    func initialLoad() async {
        if let guildId = rlAppState.currentGuild?.id, leftDrawerViewModel.accuracyLeaderboard.isEmpty {
            await leftDrawerViewModel.refreshAccuracyLeaderboard(guildId: guildId, rlAppState: rlAppState)
        }
        await refreshGlobalGuildData()
    }

    func refreshLeaderboard() async {
        async let globalTask: Void = refreshGlobalGuildData()
        if let guild = rlAppState.currentGuild {
            async let membersTask: Void = leftDrawerViewModel.refreshGuildMembers(guildId: guild.id, rlAppState: rlAppState)
            async let friendsTask: Void = leftDrawerViewModel.refreshFriends(guildId: guild.id, rlAppState: rlAppState)
            async let accuracyTask: Void = leftDrawerViewModel.refreshAccuracyLeaderboard(guildId: guild.id, rlAppState: rlAppState)
            _ = await (membersTask, friendsTask, accuracyTask, globalTask)
        } else {
            _ = await globalTask
        }
    }

    func countForPrimaryTab(_ tab: LeaderboardTab) -> Int {
        switch tab {
        case .guild:
            return selectedGuildMode == .reputation ? sortedGuildMembers.count : leftDrawerViewModel.accuracyLeaderboard.count
        case .global:
            switch selectedGlobalScope {
            case .users:
                return selectedGlobalMode == .reputation ? globalUsersByReputation.count : globalUsersByAccuracy.count
            case .guilds:
                return selectedGlobalMode == .reputation ? globalGuildsByReputation.count : globalGuildsByAccuracy.count
            }
        }
    }

    func countForGuildMode(_ mode: GuildLeaderboardMode) -> Int {
        switch mode {
        case .reputation: return sortedGuildMembers.count
        case .accuracy: return leftDrawerViewModel.accuracyLeaderboard.count
        }
    }

    func countForGlobalScope(_ scope: GlobalLeaderboardScope) -> Int {
        switch scope {
        case .users:
            return selectedGlobalMode == .reputation ? globalUsersByReputation.count : globalUsersByAccuracy.count
        case .guilds:
            return selectedGlobalMode == .reputation ? globalGuildsByReputation.count : globalGuildsByAccuracy.count
        }
    }

    func countForGlobalMode(_ mode: GlobalLeaderboardMode) -> Int {
        switch selectedGlobalScope {
        case .users:
            return mode == .reputation ? globalUsersByReputation.count : globalUsersByAccuracy.count
        case .guilds:
            return mode == .reputation ? globalGuildsByReputation.count : globalGuildsByAccuracy.count
        }
    }

    var sortedGuildMembers: [RLGuildMemberDTO] {
        leftDrawerViewModel.guildMembers.sorted { $0.reputation > $1.reputation }
    }

    var globalUsersByReputation: [GlobalUserRankEntry] {
        mergedGlobalUsers.sorted { $0.globalReputation > $1.globalReputation }
    }

    var globalUsersByAccuracy: [GlobalUserRankEntry] {
        mergedGlobalUsers
            .filter { $0.accuracyRate != nil }
            .sorted { ($0.accuracyRate ?? 0) > ($1.accuracyRate ?? 0) }
    }

    var globalGuildsByReputation: [GlobalGuildRankEntry] {
        var byId: [UUID: RLGuildDTO] = [:]
        for guild in rlAppState.userGuilds.map(\.guild) {
            byId[guild.id] = guild
        }
        for guild in discoveredGuilds {
            if let existing = byId[guild.id], existing.reputation >= guild.reputation {
                continue
            }
            byId[guild.id] = guild
        }
        return byId.values
            .sorted { $0.reputation > $1.reputation }
            .map { GlobalGuildRankEntry(guild: $0, averageAccuracy: joinedGuildAccuracy[$0.id]) }
    }

    var globalGuildsByAccuracy: [GlobalGuildRankEntry] {
        rlAppState.userGuilds
            .map(\.guild)
            .compactMap { guild in
                guard let accuracy = joinedGuildAccuracy[guild.id] else { return nil }
                return GlobalGuildRankEntry(guild: guild, averageAccuracy: accuracy)
            }
            .sorted { ($0.averageAccuracy ?? 0) > ($1.averageAccuracy ?? 0) }
    }

    var mergedGlobalUsers: [GlobalUserRankEntry] {
        var byUserId: [UUID: GlobalUserRankEntry] = [:]

        for member in leftDrawerViewModel.guildMembers {
            byUserId[member.userId] = GlobalUserRankEntry(
                userId: member.userId,
                username: member.username,
                displayName: member.displayName,
                avatarUrl: member.avatarUrl,
                isOnline: rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline),
                roleText: member.memberRole.displayName,
                roleColor: member.memberRole.color,
                isBlocked: member.isBlocked,
                isFriend: member.isFriend,
                globalReputation: member.globalReputation,
                accuracyRate: member.accuracyRate,
                guildMember: member
            )
        }

        for friend in leftDrawerViewModel.friendsRL {
            if let existing = byUserId[friend.userId] {
                byUserId[friend.userId] = GlobalUserRankEntry(
                    userId: existing.userId,
                    username: existing.username,
                    displayName: existing.displayName,
                    avatarUrl: existing.avatarUrl ?? friend.avatarUrl,
                    isOnline: rlAppState.effectiveOnlineStatus(userId: friend.userId, fallback: friend.isOnline),
                    roleText: existing.roleText,
                    roleColor: existing.roleColor,
                    isBlocked: existing.isBlocked,
                    isFriend: true,
                    globalReputation: max(existing.globalReputation, friend.globalReputation),
                    accuracyRate: existing.accuracyRate,
                    guildMember: existing.guildMember
                )
            } else {
                let role = roleForFriend(friend)
                let guildMember = leftDrawerViewModel.guildMembers.first(where: { $0.userId == friend.userId })
                byUserId[friend.userId] = GlobalUserRankEntry(
                    userId: friend.userId,
                    username: friend.username,
                    displayName: friend.displayName,
                    avatarUrl: friend.avatarUrl,
                    isOnline: rlAppState.effectiveOnlineStatus(userId: friend.userId, fallback: friend.isOnline),
                    roleText: role.text,
                    roleColor: role.color,
                    isBlocked: false,
                    isFriend: true,
                    globalReputation: friend.globalReputation,
                    accuracyRate: guildMember?.accuracyRate,
                    guildMember: guildMember
                )
            }
        }

        return Array(byUserId.values)
    }

    func refreshGlobalGuildData() async {
        isLoadingGlobalGuilds = true
        async let discoverTask = fetchDiscoverableGuilds()
        async let accuracyTask = fetchJoinedGuildAccuracy()
        discoveredGuilds = await discoverTask
        joinedGuildAccuracy = await accuracyTask
        isLoadingGlobalGuilds = false
    }

    func fetchDiscoverableGuilds() async -> [RLGuildDTO] {
        do {
            return try await rlAppState.realApi.getJoinableGuilds(sort: "reputation", limit: 100)
        } catch {
            return []
        }
    }

    func fetchJoinedGuildAccuracy() async -> [UUID: Double] {
        let joinedGuilds = rlAppState.userGuilds.map(\.guild)
        guard !joinedGuilds.isEmpty else { return [:] }

        return await withTaskGroup(of: (UUID, Double?).self) { group in
            for guild in joinedGuilds {
                group.addTask {
                    do {
                        let stats = try await rlAppState.realApi.getGuildStatistics(guildId: guild.id)
                        return (guild.id, stats.averageAccuracy)
                    } catch {
                        return (guild.id, nil)
                    }
                }
            }

            var results: [UUID: Double] = [:]
            for await (guildId, accuracy) in group {
                if let accuracy {
                    results[guildId] = accuracy
                }
            }
            return results
        }
    }

    var guildReputationContent: some View {
        Group {
            if leftDrawerViewModel.isLoadingGuildMembers && leftDrawerViewModel.guildMembers.isEmpty {
                UnifiedLoadingState(message: "Loading guild reputation...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.guildMembers.isEmpty {
                UnifiedEmptyState(
                    icon: "person.3",
                    title: "No members yet",
                    subtitle: "Guild rankings will appear here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedGuildMembers.enumerated()), id: \.element.id) { index, member in
                        LeaderboardMemberRow(
                            displayName: member.username,
                            username: member.username,
                            avatarUrl: member.avatarUrl,
                            isOnline: rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline),
                            roleText: member.memberRole.displayName,
                            roleColor: member.memberRole.color,
                            isBlocked: member.isBlocked,
                            isFriend: member.isFriend,
                            reputation: member.reputation,
                            rank: index + 1,
                            onTap: { openProfile(for: member) }
                        )
                    }
                }
            }
        }
    }

    var guildAccuracyContent: some View {
        Group {
            if leftDrawerViewModel.isLoadingAccuracyLeaderboard && leftDrawerViewModel.accuracyLeaderboard.isEmpty {
                UnifiedLoadingState(message: "Loading guild accuracy...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.accuracyLeaderboard.isEmpty {
                UnifiedEmptyState(
                    icon: "target",
                    title: "No accuracy data",
                    subtitle: "Members need at least 10 predictions to appear"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(leftDrawerViewModel.accuracyLeaderboard) { member in
                        AccuracyLeaderboardRow(
                            member: member,
                            isOnline: rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: false),
                            onTap: {
                                if let guildMember = leftDrawerViewModel.guildMembers.first(where: { $0.userId == member.userId }) {
                                    openProfile(for: guildMember)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    var globalUsersReputationContent: some View {
        Group {
            if globalUsersByReputation.isEmpty {
                UnifiedEmptyState(
                    icon: "person.2",
                    title: "No global user data",
                    subtitle: "As members and friends load, global user rankings will appear"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(globalUsersByReputation.enumerated()), id: \.element.id) { index, user in
                        LeaderboardMemberRow(
                            displayName: user.displayName,
                            username: user.username,
                            avatarUrl: user.avatarUrl,
                            isOnline: user.isOnline,
                            roleText: user.roleText,
                            roleColor: user.roleColor,
                            isBlocked: user.isBlocked,
                            isFriend: user.isFriend,
                            reputation: user.globalReputation,
                            rank: index + 1,
                            onTap: { openProfile(for: user) }
                        )
                    }
                }
            }
        }
    }

    var globalUsersAccuracyContent: some View {
        Group {
            if globalUsersByAccuracy.isEmpty {
                UnifiedEmptyState(
                    icon: "target",
                    title: "No user accuracy data",
                    subtitle: "Accuracy rankings appear when tracked members have prediction history"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(globalUsersByAccuracy.enumerated()), id: \.element.id) { index, user in
                        GlobalUserAccuracyRow(
                            username: user.username,
                            displayName: user.displayName,
                            avatarUrl: user.avatarUrl,
                            isOnline: user.isOnline,
                            accuracyRate: user.accuracyRate ?? 0,
                            rank: index + 1,
                            onTap: { openProfile(for: user) }
                        )
                    }
                }
            }
        }
    }

    var globalGuildsReputationContent: some View {
        Group {
            if isLoadingGlobalGuilds && globalGuildsByReputation.isEmpty {
                UnifiedLoadingState(message: "Loading global guilds...")
                    .padding(.top, 40)
            } else if globalGuildsByReputation.isEmpty {
                UnifiedEmptyState(
                    icon: "building.2",
                    title: "No guild data",
                    subtitle: "Global guild rankings will appear here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(globalGuildsByReputation.enumerated()), id: \.element.id) { index, guild in
                        GlobalGuildLeaderboardRow(
                            guildName: guild.name,
                            memberCount: guild.memberCount,
                            membersOnline: guild.membersOnline,
                            reputation: guild.reputationFormatted,
                            accuracyText: guild.averageAccuracy.map { String(format: "%.1f%%", $0 * 100) },
                            rank: index + 1,
                            mode: .reputation
                        )
                    }
                }
            }
        }
    }

    var globalGuildsAccuracyContent: some View {
        Group {
            if isLoadingGlobalGuilds && globalGuildsByAccuracy.isEmpty {
                UnifiedLoadingState(message: "Loading guild accuracy...")
                    .padding(.top, 40)
            } else if globalGuildsByAccuracy.isEmpty {
                UnifiedEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No guild accuracy snapshot",
                    subtitle: "Join guilds and build predictions to populate this ranking"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(globalGuildsByAccuracy.enumerated()), id: \.element.id) { index, guild in
                        GlobalGuildLeaderboardRow(
                            guildName: guild.name,
                            memberCount: guild.memberCount,
                            membersOnline: guild.membersOnline,
                            reputation: guild.reputationFormatted,
                            accuracyText: guild.accuracyFormatted,
                            rank: index + 1,
                            mode: .accuracy
                        )
                    }
                }
            }
        }
    }

    func openProfile(for entry: GlobalUserRankEntry) {
        if entry.userId == rlAppState.currentUser?.id {
            bottomSheetContent = .profile
            return
        }
        if let member = entry.guildMember {
            bottomSheetContent = .guildMemberRL(member)
        } else {
            rlAppState.showInfo("Open user profile from your guild member list for full detail")
        }
    }

    func openProfile(for member: RLGuildMemberDTO) {
        if member.userId == rlAppState.currentUser?.id {
            bottomSheetContent = .profile
        } else {
            bottomSheetContent = .guildMemberRL(member)
        }
    }

    func roleForFriend(_ friend: RLFriendDTO) -> (text: String, color: Color) {
        if let member = leftDrawerViewModel.guildMembers.first(where: { $0.userId == friend.userId }) {
            return (member.memberRole.displayName, member.memberRole.color)
        }
        return ("Friend", AppColors.friendAccent)
    }
}

private enum GlobalGuildRowMode {
    case reputation
    case accuracy
}

private struct GlobalGuildLeaderboardRow: View {
    let guildName: String
    let memberCount: Int
    let membersOnline: Int
    let reputation: String
    let accuracyText: String?
    let rank: Int
    let mode: GlobalGuildRowMode

    @State private var isPressed: Bool = false

    private var rankColor: Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.8)
        default: return AppColors.whiteText.opacity(0.5)
        }
    }

    private var rightValueColor: Color {
        switch mode {
        case .reputation:
            return AppColors.accentColor
        case .accuracy:
            return AppColors.bullCandleGreen
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 24)

            ZStack {
                Circle()
                    .fill(AppColors.whiteText.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: "shield.pattern.checkered")
                    .font(.headline)
                    .foregroundColor(AppColors.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(guildName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)

                HStack(spacing: 6) {
                    Text("\(memberCount) members")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText.opacity(0.6))
                    Text("\(membersOnline) online")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: mode == .reputation ? "shield.pattern.checkered" : "target")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text(mode == .reputation ? reputation : (accuracyText ?? "N/A"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(rightValueColor)

                if let accuracyText, mode == .reputation {
                    Text("Acc \(accuracyText)")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(isPressed ? 0.08 : 0.03))
        )
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

private struct GlobalUserAccuracyRow: View {
    let username: String
    let displayName: String
    let avatarUrl: String?
    let isOnline: Bool
    let accuracyRate: Double
    let rank: Int
    let onTap: () -> Void

    @State private var isPressed: Bool = false

    private var rankColor: Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.8)
        default: return AppColors.whiteText.opacity(0.5)
        }
    }

    private var accuracyColor: Color {
        if accuracyRate >= 0.7 { return .green }
        if accuracyRate >= 0.5 { return .yellow }
        if accuracyRate >= 0.3 { return .orange }
        return .red
    }

    private var accuracyFormatted: String {
        "\(Int(accuracyRate * 100))%"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
                    .frame(width: 24)

                UnifiedMemberAvatar(
                    username: displayName,
                    avatarURL: avatarUrl,
                    isOnline: isOnline,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)

                    Text("Tracked accuracy")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "target")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text(accuracyFormatted)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(accuracyColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.08 : 0.03))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - ================================================================================================
// MARK: - ACCURACY LEADERBOARD ROW
// MARK: - ================================================================================================

private struct AccuracyLeaderboardRow: View {
    let member: RLAccuracyLeaderboardMemberDTO
    let isOnline: Bool
    let onTap: () -> Void

    @State private var isPressed: Bool = false

    private var rankColor: Color {
        switch member.rank {
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.8)
        default: return AppColors.whiteText.opacity(0.5)
        }
    }

    private var isTopRank: Bool { member.rank <= 3 }

    /// Color based on accuracy percentage
    private var accuracyColor: Color {
        if member.accuracyRate >= 0.7 { return .green }
        if member.accuracyRate >= 0.5 { return .yellow }
        if member.accuracyRate >= 0.3 { return .orange }
        return .red
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Rank
                Text("\(member.rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
                    .frame(width: 24)

                // Avatar
                UnifiedMemberAvatar(
                    username: member.displayName,
                    avatarURL: member.avatarUrl,
                    isOnline: isOnline,
                    size: 40
                )

                // Name + stats
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)

                    HStack(spacing: 6) {
                        Text("\(member.totalPredictions) trades")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)

                        if let rr = member.rrRatioFormatted {
                            Text("R:R \(rr)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                // Accuracy percentage
                HStack(spacing: 2) {
                    Image(systemName: "target")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text(member.accuracyFormatted)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(accuracyColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.08 : (isTopRank ? 0.05 : 0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isTopRank ? rankColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - ================================================================================================
// MARK: - REPUTATION LEADERBOARD ROW
// MARK: - ================================================================================================

private struct LeaderboardMemberRow: View {
    let displayName: String
    let username: String
    let avatarUrl: String?
    let isOnline: Bool
    let roleText: String
    let roleColor: Color
    let isBlocked: Bool
    let isFriend: Bool
    let reputation: Int
    let rank: Int
    let onTap: () -> Void

    @State private var isPressed: Bool = false

    private var rankColor: Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.8)
        default: return AppColors.whiteText.opacity(0.5)
        }
    }

    private var isTopRank: Bool { rank <= 3 }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
                    .frame(width: 24)

                UnifiedMemberAvatar(
                    username: displayName,
                    avatarURL: avatarUrl,
                    isOnline: isOnline,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }

                        Text(username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isBlocked ? AppColors.greyText : AppColors.whiteText)

                        if isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(isBlocked ? AppColors.greyText : AppColors.friendAccent)
                        }
                    }

                    Text(roleText)
                        .font(.caption)
                        .foregroundColor(roleColor)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text("\(reputation)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(AppColors.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.08 : (isTopRank ? 0.05 : 0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isTopRank ? rankColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
