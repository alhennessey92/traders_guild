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
        .sheet(isPresented: $showGlobalReputationBreakdown) {
            NavigationStack {
                GlobalReputationBreakdownSheetView()
                    .environmentObject(rlAppState)
                    .navigationTitle("Global Reputation Breakdown")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showGlobalReputationBreakdown = false }
                                .foregroundColor(AppColors.accentColor)
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
                            Button("Done") { showGlobalAccuracyBreakdown = false }
                                .foregroundColor(AppColors.accentColor)
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
                ZStack(alignment: .bottomTrailing) {
                    UnifiedMemberAvatar(
                        username: rlAppState.currentUser?.username ?? "User",
                        avatarURL: rlAppState.currentUser?.avatarUrl,
                        isOnline: rlAppState.currentUser?.isOnline ?? false,
                        size: 70,
                        showOnlineIndicator: false
                    )

                    if rlAppState.currentUser?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
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
                            .foregroundColor(AppColors.accentColor)
                        Text("\(globalRepData?.globalReputation ?? rlAppState.currentUser?.globalReputation ?? 0)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("Global Reputation")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(globalAccuracyData?.accuracyFormatted ?? "--")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
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
                    .foregroundColor(.orange)
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
                    .tint(AppColors.accentColor)
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
                    color: AppColors.accentColor
                )

                GlobalStatCard(
                    title: "Global Accuracy",
                    value: globalAccuracyData?.accuracyFormatted ?? "--",
                    icon: "target",
                    color: .green
                )

                GlobalStatCard(
                    title: "Guilds Joined",
                    value: "\(globalStats?.totalGuildsJoined ?? userGuilds.count)",
                    icon: "person.3.fill",
                    color: .blue
                )

                GlobalStatCard(
                    title: "Markers Placed",
                    value: "\(globalStats?.totalMarkersPlaced ?? 0)",
                    icon: "mappin.circle.fill",
                    color: .red
                )

                GlobalStatCard(
                    title: "Active Streak",
                    value: "\(globalRepData?.consecutiveActiveDays ?? globalStats?.currentStreakDays ?? 0)d",
                    icon: "flame.fill",
                    color: .orange
                )

                GlobalStatCard(
                    title: "Awards Earned",
                    value: "\(globalStats?.totalAwardsEarned ?? 0)",
                    icon: "medal.fill",
                    color: .yellow
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
                                .foregroundColor(rep.weeklyDelta >= 0 ? .green : .red)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Global Modifier")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text(rep.modifiers.totalModifierFormatted)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .padding(.horizontal, 25)
            }

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showGlobalReputationBreakdown = true
                } label: {
                    HStack {
                        Text("Reputation Breakdown")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }

                VStack(spacing: 10) {
                    if let rep = globalRepData, !rep.guildContributions.isEmpty {
                        ForEach(rep.guildContributions, id: \.guildId) { guild in
                            ReputationBreakdownRow(
                                title: guild.guildName,
                                value: guild.reputation,
                                total: max(1, rep.globalReputation),
                                color: AppColors.accentColor
                            )
                        }
                    } else {
                        HStack {
                            Image(systemName: "shield")
                                .foregroundColor(AppColors.greyText)
                            Text("No guild contribution data available yet")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .contentShape(Rectangle())
                .onTapGesture { showGlobalReputationBreakdown = true }
            }
            .padding(.horizontal, 25)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showGlobalAccuracyBreakdown = true
                } label: {
                    HStack {
                        Text("Trading Accuracy")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }

                if let accuracy = globalAccuracyData {
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(accuracy.accuracyFormatted)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(accuracy.accuracyRate >= 0.5 ? .green : .red)
                            Text("Accuracy")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Text("\(accuracy.totalPredictions)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)
                            Text("Predictions")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Text(accuracy.rrRatioFormatted ?? "--")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("Avg R:R")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                    .onTapGesture { showGlobalAccuracyBreakdown = true }
                } else {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(AppColors.greyText)
                        Text("No global accuracy data yet")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                    .onTapGesture { showGlobalAccuracyBreakdown = true }
                }
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
                .background(Color.white.opacity(0.03))
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
                        .foregroundColor(AppColors.accentColor)
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
                    .tint(AppColors.accentColor)
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
                    .tint(AppColors.accentColor)
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
                VStack(spacing: 0) {
                    ForEach(Array(recentActivity.enumerated()), id: \.element.id) { index, activity in
                        GlobalActivityRow(
                            activity: activity,
                            isLast: index == recentActivity.count - 1
                        )
                    }
                }
                .padding(.horizontal, 25)

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
            errors.append("Global stats: \(error.localizedDescription)")
        }

        do {
            globalRepData = try await rlAppState.realApi.getMyGlobalReputation()
        } catch {
            if isCancellationError(error) { return }
            errors.append("Global reputation: \(error.localizedDescription)")
        }

        do {
            globalAccuracyData = try await rlAppState.realApi.getMyGlobalAccuracy()
        } catch {
            if isCancellationError(error) { return }
            errors.append("Global accuracy: \(error.localizedDescription)")
        }

        do {
            try await rlAppState.fetchUserGuilds()
            userGuilds = rlAppState.userGuilds
        } catch {
            if isCancellationError(error) { return }
            userGuilds = rlAppState.userGuilds
            errors.append("Guild memberships: \(error.localizedDescription)")
        }

        // /users/me/guilds updates last_seen/is_online; refresh user after this call.
        do {
            rlAppState.currentUser = try await rlAppState.realApi.getCurrentUser()
        } catch {
            if isCancellationError(error) { return }
            errors.append("Account info: \(error.localizedDescription)")
        }

        await rlAppState.refreshCurrentGuildReputation()

        do {
            let activityResponse = try await rlAppState.realApi.getUserActivity(skip: 0, limit: 100)
            recentActivity = activityResponse.items
            hasMoreActivity = activityResponse.hasMore
        } catch {
            if isCancellationError(error) { return }
            errors.append("Activity feed: \(error.localizedDescription)")
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
        let palette: [Color] = [.blue, .orange, .green, .pink, .cyan, .yellow]
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
        .background(Color.white.opacity(0.03))
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
                        .fill(Color.white.opacity(0.1))
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
                            .foregroundColor(.green)
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
                            .foregroundColor(AppColors.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accentColor.opacity(0.2))
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
                            .foregroundColor(AppColors.accentColor)
                        Text("\(guildWithMembership.membership.reputation)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    }

                    if let accuracy = guildWithMembership.membership.accuracyFormatted {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(accuracy)
                                .font(.caption)
                                .foregroundColor(.green)
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
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

struct GlobalActivityRow: View {
    let activity: RLActivityItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(activity.activityColor)
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: activity.activityIcon)
                        .font(.caption)
                        .foregroundColor(activity.activityColor)

                    Text(activity.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                }

                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                HStack(spacing: 8) {
                    Text(activity.relativeTimestamp)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText.opacity(0.7))

                    if let guild = activity.guildName {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.5))
                        Text(guild)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.7))
                    }
                }

                HStack(spacing: 6) {
                    if let guildDelta = activity.guildRepDelta {
                        ActivityDeltaBadge(label: "Guild", value: guildDelta)
                    }
                    if let globalDelta = activity.globalRepDelta {
                        ActivityDeltaBadge(label: "Global", value: globalDelta)
                    }
                    if let metricDelta = activity.metricDelta, let metricLabel = activity.metricLabel {
                        ActivityDeltaBadge(label: metricLabel.replacingOccurrences(of: "_", with: " ").capitalized, value: metricDelta)
                    }
                }
            }

            Spacer()
        }
        .padding(.bottom, isLast ? 0 : 16)
    }
}

struct ActivityDeltaBadge: View {
    let label: String
    let value: Int

    private var valueColor: Color {
        value >= 0 ? .green : .red
    }

    var body: some View {
        Text("\(label) \(value >= 0 ? "+" : "")\(value)")
            .font(.caption2)
            .foregroundColor(valueColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(valueColor.opacity(0.15))
            .cornerRadius(6)
    }
}

private extension RLActivityItem {
    var activityIcon: String {
        switch type {
        case "marker": return "mappin.circle.fill"
        case "reputation": return "shield.pattern.checkered"
        case "achievement": return "medal.fill"
        case "guild": return "person.3.fill"
        case "event": return "calendar.badge.clock"
        case "role": return "person.crop.circle.badge.checkmark"
        case "report": return "exclamationmark.bubble.fill"
        case "moderation": return "gavel.fill"
        default: return "clock.fill"
        }
    }

    var activityColor: Color {
        switch type {
        case "marker": return .red
        case "reputation": return AppColors.accentColor
        case "achievement": return .yellow
        case "guild": return .blue
        case "event": return .mint
        case "role": return .indigo
        case "report": return .orange
        case "moderation": return .purple
        default: return AppColors.greyText
        }
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

#Preview {
    UserGlobalSheetView(onBack: {})
        .environmentObject(RLAppState())
        .preferredColorScheme(.dark)
}
