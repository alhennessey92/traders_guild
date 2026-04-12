//
//  UserGlobalView.swift
//  traders_guild
//
//  Global account view backed entirely by live backend data.
//

import SwiftUI

struct UserGlobalSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    let onBack: () -> Void

    @State private var selectedTab: GlobalTab = .overview
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var loadError: String?

    @State private var globalStats: RLUserGlobalStatisticsDTO?
    @State private var userGuilds: [RLGuildWithMembership] = []
    @State private var recentActivity: [RLActivityItem] = []
    @State private var hasMoreActivity = false

    @State private var globalRepData: RLGlobalReputationDTO?
    @State private var globalAccuracyData: RLAccuracyProfileDTO?
    @State private var showGlobalReputationBreakdown = false
    @State private var showGlobalAccuracyBreakdown = false

    enum GlobalTab: String, CaseIterable, UnifiedTabItem {
        case overview
        case guilds
        case activity

        var title: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .guilds: return "person.3.fill"
            case .activity: return "clock.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                globalHeader
                tabSelector

                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .overview:
                            overviewTab
                        case .guilds:
                            guildsTab
                        case .activity:
                            activityTab
                        }

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    await loadAllData(force: false)
                }
            }
        }
        .task {
            await loadAllDataIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reputationDidUpdate)) { _ in
            Task { await loadAllData(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accuracyDidUpdate)) { _ in
            Task { await loadAllData(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard let userId = notification.userInfo?["userId"] as? UUID,
                  userId == rlAppState.currentUser?.id else { return }
            Task { await loadAllData(force: true) }
        }
        .sheet(isPresented: $showGlobalReputationBreakdown) {
            NavigationStack {
                GlobalReputationBreakdownSheetView()
                    .environmentObject(rlAppState)
                    .navigationTitle("Global Reputation Breakdown")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            SheetCloseButton(action: { showGlobalReputationBreakdown = false })
                        }
                    }
            }
        }
        .sheet(isPresented: $showGlobalAccuracyBreakdown) {
            NavigationStack {
                GlobalAccuracyBreakdownSheetView()
                    .environmentObject(rlAppState)
                    .navigationTitle("Global Accuracy Breakdown")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            SheetCloseButton(action: { showGlobalAccuracyBreakdown = false })
                        }
                    }
            }
        }
    }

    // MARK: - Header

    private var globalHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.whiteText)
                }

                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)

            HStack(spacing: 16) {
                let currentUser = rlAppState.currentUser
                ZStack(alignment: .bottomTrailing) {
                    UnifiedMemberAvatar(
                        username: currentUser?.username ?? "User",
                        avatarURL: currentUser?.avatarUrl,
                        isOnline: {
                            guard let currentUser else { return false }
                            return rlAppState.effectiveOnlineStatus(
                                userId: currentUser.id,
                                fallback: currentUser.isOnline
                            )
                        }(),
                        size: 70,
                        showOnlineIndicator: false
                    )

                    if rlAppState.currentUser?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.statusPositive)
                            .background(Circle().fill(AppColors.sheetBackground).padding(-2))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(rlAppState.currentUser?.displayName ?? "User")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)

                    Text("@\(rlAppState.currentUser?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)

                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(AppColors.guildReputationAccent)
                        Text("\(globalRepData?.globalReputation ?? rlAppState.currentUser?.globalReputation ?? 0)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.guildReputationAccent)
                        Text("Global Reputation")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundColor(AppColors.statusPositive90)
                        Text(globalAccuracyDisplay)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.statusPositive90)
                        Text("Global Accuracy")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.top, 16)
            .padding(.bottom, 16)

            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundColor(AppColors.statusWarning90)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
        }
        .background(
            LinearGradient(
                colors: [
                    AppColors.gradientBackgroundDark.opacity(0.3),
                    AppColors.sheetBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        UnifiedTabBar(
            selectedTab: $selectedTab,
            size: .compact,
            theme: .blue,
            countForTab: { tab in
                switch tab {
                case .overview: return 0
                case .guilds: return userGuilds.count
                case .activity: return recentActivity.count
                }
            },
            spacing: 6
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Overview

    private var overviewTab: some View {
        VStack(spacing: 24) {
            if isLoading && globalRepData == nil && globalStats == nil {
                ProgressView()
                    .tint(AppColors.guildReputationAccent)
                    .padding(.top, 36)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                GlobalStatCard(
                    title: "Global Reputation",
                    value: "\(globalRepData?.globalReputation ?? rlAppState.currentUser?.globalReputation ?? 0)",
                    icon: "globe",
                    color: AppColors.guildReputationAccent
                )

                GlobalStatCard(
                    title: "Global Accuracy",
                    value: globalAccuracyDisplay,
                    icon: "target",
                    color: AppColors.statusPositive
                )

                GlobalStatCard(
                    title: "Guilds Joined",
                    value: "\(globalStats?.totalGuildsJoined ?? userGuilds.count)",
                    icon: "person.3.fill",
                    color: AppColors.statusInfo
                )

                GlobalStatCard(
                    title: "Markers Placed",
                    value: "\(globalStats?.totalMarkersPlaced ?? 0)",
                    icon: "mappin.circle.fill",
                    color: AppColors.statusNegative
                )

                GlobalStatCard(
                    title: "Active Streak",
                    value: "\(globalRepData?.consecutiveActiveDays ?? globalStats?.currentStreakDays ?? 0)d",
                    icon: "flame.fill",
                    color: AppColors.moderationOrange
                )

                GlobalStatCard(
                    title: "Awards Earned",
                    value: "\(globalStats?.totalAwardsEarned ?? 0)",
                    icon: "medal.fill",
                    color: AppColors.statusHighlight80
                )
            }
            .padding(.horizontal, 25)
            .padding(.top, 16)

            if let rep = globalRepData {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Global Impact")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weekly Delta")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text("\(rep.weeklyDelta >= 0 ? "+" : "")\(rep.weeklyDelta)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(rep.weeklyDelta >= 0 ? AppColors.statusPositive : AppColors.statusNegative)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Global Modifier")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text(rep.modifiers.totalModifierFormatted)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.guildReputationAccent)
                        }
                    }
                }
                .padding()
                .background(AppColors.insetPanelBackground)
                .cornerRadius(12)
                .padding(.horizontal, 25)
            }

            VStack(spacing: 10) {
                BreakdownEntryCard(
                    title: "Global Reputation Breakdown",
                    subtitle: "Tier, weekly delta, guild contributions",
                    value: "\(globalRepData?.globalReputation ?? rlAppState.currentUser?.globalReputation ?? 0)",
                    icon: "shield.checkered",
                    iconColor: AppColors.guildReputationAccent,
                    action: { showGlobalReputationBreakdown = true }
                )

                BreakdownEntryCard(
                    title: "Global Accuracy Breakdown",
                    subtitle: "Win/loss, streaks, R:R metrics",
                    value: globalAccuracyData?.accuracyFormatted ?? "--",
                    icon: "target",
                    iconColor: AppColors.statusPositive,
                    action: { showGlobalAccuracyBreakdown = true }
                )
            }
            .padding(.horizontal, 25)

            VStack(alignment: .leading, spacing: 12) {
                Text("Account Information")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)

                VStack(spacing: 0) {
                    AccountInfoRow(
                        icon: "envelope.fill",
                        title: "Email",
                        value: rlAppState.currentUser?.email ?? "Not set",
                        isVerified: rlAppState.currentUser?.isVerified ?? false
                    )

                    Divider().padding(.leading, 50)

                    AccountInfoRow(
                        icon: "calendar",
                        title: "Member Since",
                        value: rlAppState.currentUser?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
                    )

                    Divider().padding(.leading, 50)

                    AccountInfoRow(
                        icon: "clock.fill",
                        title: "Last Active",
                        value: lastActiveDisplay
                    )
                }
                .background(AppColors.insetPanelBackground)
                .cornerRadius(12)
            }
            .padding(.horizontal, 25)
        }
    }

    // MARK: - Guilds

    private var guildsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(userGuilds.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Text("Guilds")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }

                Divider().frame(height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(userGuilds.reduce(0) { $0 + $1.membership.reputation })")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.guildReputationAccent)
                    Text("Combined Guild Rep")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.top, 16)

            if isLoading && userGuilds.isEmpty {
                ProgressView()
                    .tint(AppColors.guildReputationAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else if userGuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 42))
                        .foregroundColor(AppColors.greyText.opacity(0.6))
                    Text("No guild memberships found")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    Text("Join a guild to build your global profile.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 25)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(userGuilds.enumerated()), id: \.element.id) { index, guild in
                        GlobalGuildCard(
                            guildWithMembership: guild,
                            isCurrentGuild: guild.guild.id == rlAppState.currentGuild?.id,
                            accentColor: guildColor(for: index)
                        )
                    }
                }
                .padding(.horizontal, 25)
            }
        }
    }

    // MARK: - Activity

    private var activityTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Across All Guilds")
                .font(.headline)
                .foregroundColor(AppColors.whiteText)
                .padding(.horizontal, 25)
                .padding(.top, 16)

            if isLoading && recentActivity.isEmpty {
                ProgressView()
                    .tint(AppColors.guildReputationAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else if recentActivity.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(AppColors.greyText.opacity(0.5))

                    Text("No Activity Yet")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    Text("Your cross-guild activity and impact deltas will appear here.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .padding(.horizontal, 25)
            } else {
                UnifiedActivityTimeline(
                    items: recentActivity,
                    style: .plain,
                    horizontalPadding: 25
                )

                if hasMoreActivity {
                    Text("Showing latest activity. Pull to refresh for newer events.")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .padding(.horizontal, 25)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadAllDataIfNeeded() async {
        guard !hasLoaded else { return }
        await loadAllData(force: false)
    }

    private func loadAllData(force: Bool) async {
        if isLoading && !force { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        var errors: [String] = []

        do {
            globalStats = try await rlAppState.fetchCurrentUserStatistics()
        } catch {
            if isCancellationError(error) { return }
            errors.append("Global stats: \(RLUserFacingErrorMapper.message(from: error))")
        }

        do {
            globalRepData = try await rlAppState.realApi.getMyGlobalReputation()
        } catch {
            if isCancellationError(error) { return }
            errors.append("Global reputation: \(RLUserFacingErrorMapper.message(from: error))")
        }

        do {
            globalAccuracyData = try await rlAppState.realApi.getMyGlobalAccuracy()
            rlAppState.currentGlobalAccuracy = globalAccuracyData?.accuracyRate
        } catch {
            if isCancellationError(error) { return }
            errors.append("Global accuracy: \(RLUserFacingErrorMapper.message(from: error))")
        }

        do {
            try await rlAppState.fetchUserGuilds()
            userGuilds = rlAppState.userGuilds
        } catch {
            if isCancellationError(error) { return }
            userGuilds = rlAppState.userGuilds
            errors.append("Guild memberships: \(RLUserFacingErrorMapper.message(from: error))")
        }

        // /users/me/guilds updates last_seen/is_online; refresh user after this call.
        do {
            rlAppState.currentUser = try await rlAppState.realApi.getCurrentUser()
        } catch {
            if isCancellationError(error) { return }
            errors.append("Account info: \(RLUserFacingErrorMapper.message(from: error))")
        }

        await rlAppState.refreshCurrentGuildReputation()

        do {
            let activityResponse = try await rlAppState.realApi.getUserActivity(skip: 0, limit: 100)
            recentActivity = activityResponse.items
            hasMoreActivity = activityResponse.hasMore
        } catch {
            if isCancellationError(error) { return }
            errors.append("Activity feed: \(RLUserFacingErrorMapper.message(from: error))")
        }

        if !errors.isEmpty {
            loadError = errors.joined(separator: " • ")
        }

        hasLoaded = true
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        if case let APIError.networkError(message) = error,
           message.lowercased().contains("cancelled") {
            return true
        }
        return false
    }

    private func guildColor(for index: Int) -> Color {
        let palette: [Color] = [
            AppColors.statusInfo,
            AppColors.moderationOrange,
            AppColors.statusPositive,
            AppColors.guildReputationAccent,
            AppColors.statusWarning70,
            AppColors.statusHighlight80
        ]
        return palette[index % palette.count]
    }

    private var lastActiveDisplay: String {
        guard let user = rlAppState.currentUser else { return "Unknown" }
        if rlAppState.effectiveOnlineStatus(userId: user.id, fallback: user.isOnline) {
            return "Active now"
        }
        if let lastSeenAt = user.lastSeenAt {
            return lastSeenAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Unknown"
    }

    private var globalAccuracyDisplay: String {
        if let globalAccuracyData {
            return globalAccuracyData.accuracyFormatted
        }
        if let currentGlobalAccuracy = rlAppState.currentGlobalAccuracy {
            return "\(Int(currentGlobalAccuracy * 100))%"
        }
        return "--"
    }
}

// MARK: - Supporting Components

struct GlobalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)

            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
        .padding()
        .background(AppColors.insetPanelBackground)
        .cornerRadius(12)
    }
}

struct ReputationBreakdownRow: View {
    let title: String
    let value: Int
    let total: Int
    let color: Color

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)

                Spacer()

                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.panelFillEmphasis)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct AccountInfoRow: View {
    let icon: String
    let title: String
    let value: String
    var isVerified: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(AppColors.greyText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                HStack(spacing: 6) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)

                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.statusPositive)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct GlobalGuildCard: View {
    let guildWithMembership: RLGuildWithMembership
    let isCurrentGuild: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(accentColor.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(guildWithMembership.guild.name.prefix(2)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(accentColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(guildWithMembership.guild.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)

                    if isCurrentGuild {
                        Text("CURRENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.guildReputationAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.guildReputationAccent.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(guildWithMembership.membership.memberRole.color)
                        Text(guildWithMembership.membership.memberRole.displayName)
                            .font(.caption)
                            .foregroundColor(guildWithMembership.membership.memberRole.color)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .foregroundColor(AppColors.guildReputationAccent)
                        Text("\(guildWithMembership.membership.reputation)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.guildReputationAccent)
                    }

                    if let accuracy = guildWithMembership.membership.accuracyFormatted {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                                .foregroundColor(AppColors.statusPositive90)
                            Text(accuracy)
                                .font(.caption)
                                .foregroundColor(AppColors.statusPositive90)
                        }
                    }
                }

                Text("\(guildWithMembership.guild.memberCountDisplay) members")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer()
        }
        .padding(14)
        .background(AppColors.insetPanelBackground)
        .cornerRadius(12)
    }
}

#Preview {
    UserGlobalSheetView(onBack: {})
        .environmentObject(RLAppState())
        .preferredColorScheme(ThemeManager.shared.currentTheme.colorScheme)
}
