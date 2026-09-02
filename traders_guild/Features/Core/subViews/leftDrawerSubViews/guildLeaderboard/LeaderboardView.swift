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
        case .reputation: return ReputationGlyph.symbolName
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
        case .reputation: return ReputationGlyph.symbolName
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
    let guildName: String?
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
    @State private var globalUserLeaderboard: [RLGlobalUserLeaderboardMemberDTO] = []
    @State private var isLoadingGlobalUsers: Bool = false
    @State private var currentGuildAccuracyProfile: RLAccuracyProfileDTO? = nil
    @State private var hasLoadedGuildAccuracyLeaderboard = false
    @State private var hasLoadedCurrentGuildAccuracyProfile = false
    @State private var hasLoadedGlobalUsers = false
    @State private var hasLoadedDiscoverableGuilds = false
    @State private var hasLoadedJoinedGuildAccuracy = false
    @State private var guildAccuracyRefreshHint: String? = nil
    @State private var discordChannels: [RLGuildDiscordChannelDTO] = []
    @State private var showLeaderboardShare = false
    @State private var showMyStatsShare = false
    @State private var isSettingPublicLeaderboard = false
    @State private var globalUsersRefreshHint: String? = nil
    @State private var globalGuildsRefreshHint: String? = nil

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
                    theme: .subTab,
                    countForTab: { tab in countForGuildMode(tab) },
                    spacing: 6
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                UnifiedTabBar(
                    selectedTab: $selectedGlobalScope,
                    size: .compact,
                    theme: .subTab,
                    countForTab: { tab in countForGlobalScope(tab) },
                    spacing: 6
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                UnifiedTabBar(
                    selectedTab: $selectedGlobalMode,
                    size: .compact,
                    theme: .subTab,
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
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard let guildId = notification.userInfo?["guildId"] as? UUID,
                  let guildAverageAccuracy = notification.userInfo?["guildAverageAccuracy"] as? Double else { return }
            joinedGuildAccuracy[guildId] = guildAverageAccuracy
        }
    }
}

private extension LeaderboardListView {
    func initialLoad() async {
        if let guildId = rlAppState.currentGuild?.id {
            let leaderboardLoaded: Bool
            if leftDrawerViewModel.accuracyLeaderboard.isEmpty {
                leaderboardLoaded = await leftDrawerViewModel.refreshAccuracyLeaderboard(guildId: guildId, rlAppState: rlAppState)
            } else {
                hasLoadedGuildAccuracyLeaderboard = true
                leaderboardLoaded = true
            }
            let profileLoaded = await refreshCurrentGuildAccuracyProfile(guildId: guildId)
            updateGuildAccuracyRefreshHint(
                leaderboardLoaded: leaderboardLoaded,
                profileLoaded: profileLoaded
            )
        }
        await refreshGlobalUsers()
        await refreshGlobalGuildData()
        await loadDiscordChannels()
    }

    func refreshLeaderboard() async {
        async let globalTask: Void = refreshGlobalGuildData()
        async let globalUsersTask: Void = refreshGlobalUsers()
        if let guild = rlAppState.currentGuild {
            async let membersTask: Void = leftDrawerViewModel.refreshGuildMembers(guildId: guild.id, rlAppState: rlAppState)
            async let friendsTask: Void = leftDrawerViewModel.refreshFriends(guildId: guild.id, rlAppState: rlAppState)
            async let accuracyTask: Bool = leftDrawerViewModel.refreshAccuracyLeaderboard(guildId: guild.id, rlAppState: rlAppState)
            async let currentAccuracyTask: Bool = refreshCurrentGuildAccuracyProfile(guildId: guild.id)
            let leaderboardLoaded = await accuracyTask
            let profileLoaded = await currentAccuracyTask
            updateGuildAccuracyRefreshHint(
                leaderboardLoaded: leaderboardLoaded,
                profileLoaded: profileLoaded
            )
            _ = await (membersTask, friendsTask, globalTask, globalUsersTask)
        } else {
            _ = await (globalTask, globalUsersTask)
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
        globalUserLeaderboard
            .sorted { $0.globalReputation > $1.globalReputation }
            .map(globalEntry)
    }

    var globalUsersByAccuracy: [GlobalUserRankEntry] {
        globalUserLeaderboard
            .filter { $0.totalPredictions > 0 }
            .sorted { $0.accuracyRate > $1.accuracyRate }
            .map(globalEntry)
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

    func globalEntry(from member: RLGlobalUserLeaderboardMemberDTO) -> GlobalUserRankEntry {
        let guildMember = leftDrawerViewModel.guildMembers.first(where: { $0.userId == member.userId })
        let roleText = member.guildRole?.capitalized ?? (member.guildName == nil ? "No Guild" : "Guild Member")
        return GlobalUserRankEntry(
            userId: member.userId,
            username: member.username,
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
            isOnline: rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline),
            roleText: roleText,
            roleColor: AppColors.greyText,
            isBlocked: guildMember?.isBlocked ?? false,
            isFriend: guildMember?.isFriend ?? false,
            globalReputation: member.globalReputation,
            accuracyRate: member.accuracyRate,
            guildName: member.guildName,
            guildMember: guildMember
        )
    }

    func refreshGlobalUsers() async {
        let hadCachedData = hasLoadedGlobalUsers || !globalUserLeaderboard.isEmpty
        isLoadingGlobalUsers = true
        defer { isLoadingGlobalUsers = false }
        let endpoint = "/reputation/global-users-leaderboard"
        logLeaderboardRefresh(
            "global-users",
            status: "start",
            detail: "endpoint=\(endpoint) cached=\(hadCachedData)"
        )
        do {
            let response = try await rlAppState.realApi.getGlobalUsersLeaderboard(limit: 100, minPredictions: 0)
            globalUserLeaderboard = response.members
            hasLoadedGlobalUsers = true
            globalUsersRefreshHint = nil
            logLeaderboardRefresh(
                "global-users",
                status: "success",
                detail: "endpoint=\(endpoint) resultClass=success members=\(response.members.count)"
            )
        } catch {
            logLeaderboardRefresh(
                "global-users",
                status: "failure",
                detail: leaderboardRefreshDiagnostic(
                    endpoint: endpoint,
                    error: error
                )
            )
            globalUsersRefreshHint = hadCachedData
                ? nil
                : initialLoadRefreshHint
        }
    }

    @discardableResult
    func refreshCurrentGuildAccuracyProfile(guildId: UUID) async -> Bool {
        let endpoint = "/reputation/me/accuracy/guild/\(guildId.uuidString)"
        logLeaderboardRefresh(
            "guild-accuracy-profile",
            status: "start",
            detail: "endpoint=\(endpoint) guildId=\(guildId.uuidString)"
        )
        do {
            currentGuildAccuracyProfile = try await rlAppState.realApi.getMyGuildAccuracy(guildId: guildId)
            hasLoadedCurrentGuildAccuracyProfile = true
            logLeaderboardRefresh(
                "guild-accuracy-profile",
                status: "success",
                detail: "endpoint=\(endpoint) resultClass=success guildId=\(guildId.uuidString) totalPredictions=\(currentGuildAccuracyProfile?.totalPredictions ?? 0)"
            )
            return true
        } catch {
            logLeaderboardRefresh(
                "guild-accuracy-profile",
                status: "failure",
                detail: leaderboardRefreshDiagnostic(
                    endpoint: endpoint,
                    error: error,
                    extra: "guildId=\(guildId.uuidString)"
                )
            )
            return false
        }
    }

    func refreshGlobalGuildData() async {
        isLoadingGlobalGuilds = true
        defer { isLoadingGlobalGuilds = false }
        logLeaderboardRefresh("global-guilds", status: "start")

        async let discoverTask = fetchDiscoverableGuilds()
        async let accuracyTask = fetchJoinedGuildAccuracy()
        let discoverResult = await discoverTask
        let accuracyResult = await accuracyTask

        if discoverResult.didSucceed {
            discoveredGuilds = discoverResult.guilds
            hasLoadedDiscoverableGuilds = true
        }

        if accuracyResult.didSucceed {
            joinedGuildAccuracy = accuracyResult.accuracyByGuild
            hasLoadedJoinedGuildAccuracy = true
        }

        if discoverResult.didSucceed && accuracyResult.didSucceed {
            globalGuildsRefreshHint = nil
            logLeaderboardRefresh(
                "global-guilds",
                status: "success",
                detail: "discoverable=\(discoveredGuilds.count) joinedAccuracy=\(joinedGuildAccuracy.count)"
            )
        } else {
            let hadCachedData = hasLoadedDiscoverableGuilds || hasLoadedJoinedGuildAccuracy || !discoveredGuilds.isEmpty || !joinedGuildAccuracy.isEmpty
            globalGuildsRefreshHint = hadCachedData
                ? nil
                : initialLoadRefreshHint
            logLeaderboardRefresh(
                "global-guilds",
                status: "failure",
                detail: "discover=\(discoverResult.didSucceed) accuracy=\(accuracyResult.didSucceed)"
            )
        }
    }

    func fetchDiscoverableGuilds() async -> (guilds: [RLGuildDTO], didSucceed: Bool) {
        do {
            return (try await rlAppState.realApi.getJoinableGuilds(sort: "reputation", limit: 100), true)
        } catch {
            return ([], false)
        }
    }

    func fetchJoinedGuildAccuracy() async -> (accuracyByGuild: [UUID: Double], didSucceed: Bool) {
        let joinedGuilds = rlAppState.userGuilds.map(\.guild)
        guard !joinedGuilds.isEmpty else { return ([:], true) }

        return await withTaskGroup(of: (UUID, Double?, Bool).self) { group in
            for guild in joinedGuilds {
                group.addTask {
                    do {
                        let stats = try await rlAppState.realApi.getGuildStatistics(guildId: guild.id)
                        return (guild.id, stats.averageAccuracy, true)
                    } catch {
                        return (guild.id, nil, false)
                    }
                }
            }

            var results: [UUID: Double] = [:]
            var didSucceed = false
            for await (guildId, accuracy, requestSucceeded) in group {
                didSucceed = didSucceed || requestSucceeded
                if let accuracy {
                    results[guildId] = accuracy
                }
            }
            return (results, didSucceed)
        }
    }

    var staleRefreshHint: String {
        "Live refresh unavailable. Showing last update."
    }

    var initialLoadRefreshHint: String {
        "Leaderboard unavailable right now. Pull to retry."
    }

    var hasGuildAccuracyCachedData: Bool {
        hasLoadedGuildAccuracyLeaderboard
            || hasLoadedCurrentGuildAccuracyProfile
            || !leftDrawerViewModel.accuracyLeaderboard.isEmpty
            || currentGuildAccuracyProfile != nil
    }

    func updateGuildAccuracyRefreshHint(leaderboardLoaded: Bool, profileLoaded: Bool) {
        if leaderboardLoaded {
            hasLoadedGuildAccuracyLeaderboard = true
        }
        if profileLoaded {
            hasLoadedCurrentGuildAccuracyProfile = true
        }

        if leaderboardLoaded && profileLoaded {
            guildAccuracyRefreshHint = nil
        } else if hasGuildAccuracyCachedData {
            guildAccuracyRefreshHint = nil
        } else {
            guildAccuracyRefreshHint = initialLoadRefreshHint
        }

        logLeaderboardRefresh(
            "guild-accuracy",
            status: leaderboardLoaded && profileLoaded ? "success" : "failure",
            detail: "leaderboardLoaded=\(leaderboardLoaded) profileLoaded=\(profileLoaded) cached=\(hasGuildAccuracyCachedData)"
        )
    }

    func logLeaderboardRefresh(_ surface: String, status: String, detail: String? = nil) {
        if let detail, !detail.isEmpty {
            print("📊 [Leaderboard] \(surface) \(status) \(detail)")
        } else {
            print("📊 [Leaderboard] \(surface) \(status)")
        }
    }

    func leaderboardRefreshDiagnostic(
        endpoint: String,
        error: Error,
        extra: String? = nil
    ) -> String {
        let suffix = extra.map { " \($0)" } ?? ""
        switch error {
        case let apiError as APIError:
            switch apiError {
            case .serverError(let statusCode, let detail):
                return "endpoint=\(endpoint) resultClass=http status=\(statusCode) reason=\(detail)\(suffix)"
            case .badRequest(let detail):
                return "endpoint=\(endpoint) resultClass=badRequest status=400 reason=\(detail)\(suffix)"
            case .networkError(let detail):
                return "endpoint=\(endpoint) resultClass=network reason=\(detail)\(suffix)"
            case .decodingError(let detail):
                return "endpoint=\(endpoint) resultClass=decode reason=\(detail)\(suffix)"
            case .unauthorized:
                return "endpoint=\(endpoint) resultClass=http status=401 reason=unauthorized\(suffix)"
            case .invalidURL:
                return "endpoint=\(endpoint) resultClass=client reason=invalid_url\(suffix)"
            case .invalidResponse:
                return "endpoint=\(endpoint) resultClass=client reason=invalid_response\(suffix)"
            }
        default:
            return "endpoint=\(endpoint) resultClass=\(String(describing: type(of: error))) reason=\(String(describing: error))\(suffix)"
        }
    }

    @ViewBuilder
    func refreshHintBanner(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.caption.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .lineLimit(2)
            }
            .foregroundColor(AppColors.chartAxisLabelSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.messagingListRowFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
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
        VStack(spacing: 10) {
            accuracyWindowPicker

            Group {
                if (leftDrawerViewModel.isLoadingAccuracyLeaderboard || !hasLoadedGuildAccuracyLeaderboard)
                    && leftDrawerViewModel.accuracyLeaderboard.isEmpty {
                    VStack(spacing: 10) {
                        refreshHintBanner(guildAccuracyRefreshHint)
                        UnifiedLoadingState(message: "Loading guild accuracy...")
                            .padding(.top, 40)
                    }
                } else if leftDrawerViewModel.accuracyLeaderboard.isEmpty {
                    VStack(spacing: 10) {
                        refreshHintBanner(guildAccuracyRefreshHint)
                        if let progressCard = guildAccuracyProgressCard {
                            progressCard
                        }
                        UnifiedEmptyState(
                            icon: "target",
                            title: emptyAccuracyTitle,
                            subtitle: emptyAccuracySubtitle
                        )
                        .padding(.top, 20)
                        discordConnectNudge
                        publicLeaderboardRow
                    }
                } else {
                    VStack(spacing: 10) {
                        refreshHintBanner(guildAccuracyRefreshHint)
                        if let progressCard = guildAccuracyProgressCard {
                            progressCard
                        }
                        myRecordCard
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
                        discordConnectNudge
                        publicLeaderboardRow
                    }
                }
            }
        }
    }

    /// Where the public standings live, said on the screen they describe.
    ///
    /// The toggle itself is in guild settings under the access options, which
    /// is a reasonable home and a terrible place to discover it from. Owners
    /// were finding neither the setting nor, once it was on, the address —
    /// so both live here, one tap from the board they publish.
    @ViewBuilder
    private var publicLeaderboardRow: some View {
        if canManageGuild, let guild = rlAppState.currentGuild {
            let isPublished = guild.publicLeaderboard ?? false
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: isPublished ? "globe" : "eye.slash.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(
                            isPublished ? AppColors.guildReputationAccent : AppColors.greyText
                        )
                    Text(isPublished ? "Standings are public" : "Standings are private")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.whiteText)
                    Spacer()
                    Button {
                        Task { await setPublicLeaderboard(!isPublished) }
                    } label: {
                        Text(isPublished ? "Make private" : "Publish")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(AppColors.guildReputationAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().stroke(
                                    AppColors.guildReputationAccent.opacity(0.45), lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSettingPublicLeaderboard)
                }

                if isPublished, let url = LeaderboardShare.publicURL(
                    slug: guild.slug, window: .all
                ) {
                    Button {
                        UIPasteboard.general.string = url.absoluteString
                        HapticFeedback.success.trigger()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                            Text(url.absoluteString.replacingOccurrences(of: "https://", with: ""))
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .foregroundColor(AppColors.greyText)
                    }
                    .buttonStyle(.plain)
                } else if !isPublished {
                    Text("Publish to get a link anyone can open — no app needed.")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.insetPanelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
        }
    }

    private func setPublicLeaderboard(_ enabled: Bool) async {
        guard !isSettingPublicLeaderboard else { return }
        isSettingPublicLeaderboard = true
        defer { isSettingPublicLeaderboard = false }
        _ = try? await rlAppState.updateGuild(
            name: nil,
            description: nil,
            isOpen: nil,
            publicLeaderboard: enabled
        )
    }

    /// Week / Month / All time.
    ///
    /// The all-time board is the app's oldest view and stays the default; the
    /// short windows are what make "trader of the month" a real thing you can
    /// look at rather than a claim somebody makes in chat.
    private var accuracyWindowPicker: some View {
        HStack(spacing: 6) {
            shareStandingsButton
            ForEach(LeaderboardWindow.allCases) { window in
                let isSelected = leftDrawerViewModel.accuracyLeaderboardWindow == window
                Button {
                    guard !isSelected, let guildId = rlAppState.currentGuild?.id else { return }
                    HapticFeedback.light.trigger()
                    Task {
                        await leftDrawerViewModel.refreshAccuracyLeaderboard(
                            guildId: guildId,
                            rlAppState: rlAppState,
                            window: window
                        )
                    }
                } label: {
                    Text(window.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(isSelected ? AppColors.guildReputationAccent : AppColors.greyText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? AppColors.guildReputationAccent.opacity(0.16) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(
                                            isSelected
                                                ? AppColors.guildReputationAccent.opacity(0.55)
                                                : AppColors.surfaceWhite12,
                                            lineWidth: isSelected ? 1.4 : 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(leftDrawerViewModel.isLoadingAccuracyLeaderboard)
    }

    /// The current user's own record, with a way to post it.
    ///
    /// Somebody who is doing well is the most motivated distributor Traders
    /// Guild has: their record is only credible *because* it was tracked
    /// automatically, which is the whole pitch in one screenshot.
    @ViewBuilder
    private var myRecordCard: some View {
        if let profile = currentGuildAccuracyProfile,
           profile.totalPredictions >= leftDrawerViewModel.accuracyLeaderboardMinPredictions {
            let accuracy = Int((profile.accuracyRate * 100).rounded())
            let losses = max(0, profile.totalPredictions - profile.successfulPredictions)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your record")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(AppColors.guildReputationAccent)
                    HStack(spacing: 6) {
                        Text("\(accuracy)%")
                            .font(.title3.weight(.bold))
                            .foregroundColor(AppColors.whiteText)
                        Text("\(profile.successfulPredictions)W · \(losses)L")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        if let rank = profile.rankInGuild {
                            Text("· #\(rank)")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                    }
                }
                Spacer()
                Button {
                    HapticFeedback.light.trigger()
                    showMyStatsShare = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.guildReputationAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().stroke(
                                AppColors.guildReputationAccent.opacity(0.45), lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.messagingListRowFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
            .sheet(isPresented: $showMyStatsShare) {
                if let guild = rlAppState.currentGuild {
                    MemberStatsShareSheet(
                        guildName: guild.name,
                        guildSlug: guild.slug,
                        isPublished: guild.publicLeaderboard ?? false,
                        window: leftDrawerViewModel.accuracyLeaderboardWindow,
                        profile: profile,
                        rank: profile.rankInGuild,
                        username: rlAppState.currentUser?.username
                    )
                }
            }
        }
    }

    /// Standings are only worth sharing once there are some.
    @ViewBuilder
    private var shareStandingsButton: some View {
        if !leftDrawerViewModel.accuracyLeaderboard.isEmpty {
            Button {
                HapticFeedback.light.trigger()
                showLeaderboardShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.guildReputationAccent)
                    .frame(width: 34)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showLeaderboardShare) {
                if let guild = rlAppState.currentGuild {
                    LeaderboardShareSheet(
                        guildId: guild.id,
                        guildName: guild.name,
                        guildSlug: guild.slug,
                        isPublished: guild.publicLeaderboard ?? false,
                        window: leftDrawerViewModel.accuracyLeaderboardWindow,
                        members: leftDrawerViewModel.accuracyLeaderboard,
                        channels: discordChannels
                    )
                    .environmentObject(rlAppState)
                }
            }
        }
    }

    /// Shown to admins whose guild has no Discord channel connected.
    ///
    /// The standings are the thing a trading Discord actually wants from
    /// Traders Guild, and this screen is where an owner is most likely to
    /// realise that — so the prompt to connect one belongs here rather than
    /// buried in settings, which is the only place it currently lives.
    @ViewBuilder
    private var discordConnectNudge: some View {
        if canManageGuild && discordChannels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image("DiscordLogo")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15, height: 15)
                        .foregroundColor(AppColors.guildReputationAccent)
                    Text("Post these standings to your Discord")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.whiteText)
                }
                Text("Connect a channel and your guild's leaderboard — and every tracked setup's result — can post there automatically.")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Guild settings → Discord")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.guildReputationAccent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.guildReputationAccent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.guildReputationAccent.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.top, 4)
        }
    }

    private var canManageGuild: Bool {
        rlAppState.canAdmin
    }

    /// Best-effort: the share sheet and the nudge both degrade quietly when
    /// Discord config cannot be read.
    private func loadDiscordChannels() async {
        guard let guildId = rlAppState.currentGuild?.id else {
            discordChannels = []
            return
        }
        if let response = try? await rlAppState.realApi.getGuildDiscordChannels(guildId: guildId) {
            discordChannels = response.channels
        } else {
            discordChannels = []
        }
    }

    private var emptyAccuracyTitle: String {
        leftDrawerViewModel.accuracyLeaderboardWindow == .all
            ? "No accuracy data"
            : "Nothing resolved yet"
    }

    private var emptyAccuracySubtitle: String {
        let window = leftDrawerViewModel.accuracyLeaderboardWindow
        if window == .all {
            return "Members need at least \(leftDrawerViewModel.accuracyLeaderboardMinPredictions) predictions to appear"
        }
        return "No tracked setup has hit its target or stop in the \(window.caption.lowercased())"
    }

    var globalUsersReputationContent: some View {
        Group {
            if (isLoadingGlobalUsers || !hasLoadedGlobalUsers) && globalUsersByReputation.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalUsersRefreshHint)
                    UnifiedLoadingState(message: "Loading global users...")
                        .padding(.top, 40)
                }
            } else if globalUsersByReputation.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalUsersRefreshHint)
                    UnifiedEmptyState(
                        icon: "person.2",
                        title: "No global user data",
                        subtitle: "Global user rankings will appear once the leaderboard loads"
                    )
                    .padding(.top, 40)
                }
            } else {
                VStack(spacing: 10) {
                    refreshHintBanner(globalUsersRefreshHint)
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
                                secondaryLabel: user.guildName,
                                rank: index + 1,
                                onTap: { openProfile(for: user) }
                            )
                        }
                    }
                }
            }
        }
    }

    var globalUsersAccuracyContent: some View {
        Group {
            if (isLoadingGlobalUsers || !hasLoadedGlobalUsers) && globalUsersByAccuracy.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalUsersRefreshHint)
                    UnifiedLoadingState(message: "Loading user accuracy...")
                        .padding(.top, 40)
                }
            } else if globalUsersByAccuracy.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalUsersRefreshHint)
                    UnifiedEmptyState(
                        icon: "target",
                        title: "No user accuracy data",
                        subtitle: "Accuracy rankings appear when global prediction history is available"
                    )
                    .padding(.top, 40)
                }
            } else {
                VStack(spacing: 10) {
                    refreshHintBanner(globalUsersRefreshHint)
                    LazyVStack(spacing: 8) {
                        ForEach(Array(globalUsersByAccuracy.enumerated()), id: \.element.id) { index, user in
                            GlobalUserAccuracyRow(
                                username: user.username,
                                displayName: user.displayName,
                                avatarUrl: user.avatarUrl,
                                isOnline: user.isOnline,
                                accuracyRate: user.accuracyRate ?? 0,
                                contextLabel: user.guildName,
                                rank: index + 1,
                                onTap: { openProfile(for: user) }
                            )
                        }
                    }
                }
            }
        }
    }

    var globalGuildsReputationContent: some View {
        Group {
            if (isLoadingGlobalGuilds || !hasLoadedDiscoverableGuilds) && globalGuildsByReputation.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalGuildsRefreshHint)
                    UnifiedLoadingState(message: "Loading global guilds...")
                        .padding(.top, 40)
                }
            } else if globalGuildsByReputation.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalGuildsRefreshHint)
                    UnifiedEmptyState(
                        icon: "building.2",
                        title: "No guild data",
                        subtitle: "Global guild rankings will appear here"
                    )
                    .padding(.top, 40)
                }
            } else {
                VStack(spacing: 10) {
                    refreshHintBanner(globalGuildsRefreshHint)
                    LazyVStack(spacing: 8) {
                        ForEach(Array(globalGuildsByReputation.enumerated()), id: \.element.id) { index, guild in
                            GuildCardView(
                                guild: guild.guild,
                                style: .compact,
                                rank: index + 1,
                                stats: GuildCardStats(
                                    members: guild.memberCount,
                                    online: guild.membersOnline,
                                    reputation: guild.reputationFormatted
                                ),
                                trailingMetric: guild.reputationFormatted
                            )
                        }
                    }
                }
            }
        }
    }

    var globalGuildsAccuracyContent: some View {
        Group {
            if (isLoadingGlobalGuilds || !hasLoadedJoinedGuildAccuracy) && globalGuildsByAccuracy.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalGuildsRefreshHint)
                    UnifiedLoadingState(message: "Loading guild accuracy...")
                        .padding(.top, 40)
                }
            } else if globalGuildsByAccuracy.isEmpty {
                VStack(spacing: 10) {
                    refreshHintBanner(globalGuildsRefreshHint)
                    UnifiedEmptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No guild accuracy snapshot",
                        subtitle: "Join guilds and build predictions to populate this ranking"
                    )
                    .padding(.top, 40)
                }
            } else {
                VStack(spacing: 10) {
                    refreshHintBanner(globalGuildsRefreshHint)
                    LazyVStack(spacing: 8) {
                        ForEach(Array(globalGuildsByAccuracy.enumerated()), id: \.element.id) { index, guild in
                            GuildCardView(
                                guild: guild.guild,
                                style: .compact,
                                rank: index + 1,
                                stats: GuildCardStats(
                                    members: guild.memberCount,
                                    online: guild.membersOnline,
                                    reputation: guild.reputationFormatted
                                ),
                                trailingMetric: guild.accuracyFormatted,
                                trailingMetricColor: AppColors.statusPositive
                            )
                        }
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

    var guildAccuracyProgressCard: AnyView? {
        guard let currentGuildAccuracyProfile,
              currentGuildAccuracyProfile.totalPredictions > 0,
              currentGuildAccuracyProfile.totalPredictions < leftDrawerViewModel.accuracyLeaderboardMinPredictions else {
            return nil
        }

        let remaining = max(0, leftDrawerViewModel.accuracyLeaderboardMinPredictions - currentGuildAccuracyProfile.totalPredictions)
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)

                Text("\(currentGuildAccuracyProfile.totalPredictions) predictions logged. \(remaining) more needed for the guild ranking.")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                ProgressView(
                    value: Double(currentGuildAccuracyProfile.totalPredictions),
                    total: Double(leftDrawerViewModel.accuracyLeaderboardMinPredictions)
                )
                .tint(AppColors.accentColor)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.messagingListRowFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
        )
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

private struct GlobalUserAccuracyRow: View {
    let username: String
    let displayName: String
    let avatarUrl: String?
    let isOnline: Bool
    let accuracyRate: Double
    let contextLabel: String?
    let rank: Int
    let onTap: () -> Void

    @State private var isPressed: Bool = false

    private var rankColor: Color {
        switch rank {
        case 1: return AppColors.markerViewingTintPrimaryStar
        case 2: return AppColors.surfaceGray80
        case 3: return AppColors.statusWarning80
        default: return AppColors.whiteText.opacity(0.5)
        }
    }

    private var accuracyColor: Color {
        if accuracyRate >= 0.7 { return AppColors.statusPositive }
        if accuracyRate >= 0.5 { return AppColors.statusHighlight80 }
        if accuracyRate >= 0.3 { return AppColors.moderationOrange }
        return AppColors.statusNegative
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

                    if let contextLabel, !contextLabel.isEmpty {
                        Text(contextLabel)
                            .font(.caption2)
                            .foregroundColor(AppColors.guildReputationAccent)
                    }
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
                    .fill(isPressed ? AppColors.messagingListRowFillPressed : AppColors.messagingListRowFill)
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
        case 1: return AppColors.markerViewingTintPrimaryStar
        case 2: return AppColors.surfaceGray80
        case 3: return AppColors.statusWarning80
        default: return AppColors.whiteText.opacity(0.5)
        }
    }

    private var isTopRank: Bool { member.rank <= 3 }

    /// Color based on accuracy percentage
    private var accuracyColor: Color {
        if member.accuracyRate >= 0.7 { return AppColors.statusPositive }
        if member.accuracyRate >= 0.5 { return AppColors.statusHighlight80 }
        if member.accuracyRate >= 0.3 { return AppColors.moderationOrange }
        return AppColors.statusNegative
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
                                .foregroundColor(AppColors.statusWarning72)
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
                    .fill(AppColors.leaderboardRowFill(isTopRank: isTopRank, isPressed: isPressed))
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
    let secondaryLabel: String?
    let rank: Int
    let onTap: () -> Void

    @State private var isPressed: Bool = false

    init(
        displayName: String,
        username: String,
        avatarUrl: String?,
        isOnline: Bool,
        roleText: String,
        roleColor: Color,
        isBlocked: Bool,
        isFriend: Bool,
        reputation: Int,
        secondaryLabel: String? = nil,
        rank: Int,
        onTap: @escaping () -> Void
    ) {
        self.displayName = displayName
        self.username = username
        self.avatarUrl = avatarUrl
        self.isOnline = isOnline
        self.roleText = roleText
        self.roleColor = roleColor
        self.isBlocked = isBlocked
        self.isFriend = isFriend
        self.reputation = reputation
        self.secondaryLabel = secondaryLabel
        self.rank = rank
        self.onTap = onTap
    }

    private var rankColor: Color {
        switch rank {
        case 1: return AppColors.markerViewingTintPrimaryStar
        case 2: return AppColors.surfaceGray80
        case 3: return AppColors.statusWarning80
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

                    if let secondaryLabel, !secondaryLabel.isEmpty {
                        Text(secondaryLabel)
                            .font(.caption2)
                            .foregroundColor(AppColors.accentColor)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 2) {
                    ReputationGlyph(size: 11)
                    Text("\(reputation)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(AppColors.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.leaderboardRowFill(isTopRank: isTopRank, isPressed: isPressed))
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
