// =============================================================================
// ReputationDetailView.swift
//
// Full reputation detail view accessible from the user's profile.
// Shows tier progress, breakdown, guild contributions, modifiers,
// recent history feed, and leaderboard preview.
// =============================================================================

import SwiftUI

struct ReputationDetailView: View {
    @EnvironmentObject var rlAppState: RLAppState

    // Data
    @State private var guildProfile: RLReputationProfileDTO?
    @State private var globalReputation: RLGlobalReputationDTO?
    @State private var leaderboard: RLReputationLeaderboardDTO?
    @State private var historyEvents: [RLReputationEventDTO] = []
    @State private var historyHasMore = false
    @State private var historyPage = 1
    @State private var tiers: [RLReputationTierDTO] = []

    // UI State
    @State private var selectedTab: RepTab = .guild
    @State private var isLoading = true
    @State private var errorMessage: String?

    enum RepTab: String, CaseIterable {
        case guild = "Guild"
        case global = "Global"
        case history = "History"

        var icon: String {
            switch self {
            case .guild:   return "person.3.fill"
            case .global:  return "globe"
            case .history: return "clock.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Tab Picker
                tabPicker

                if isLoading {
                    ProgressView()
                        .tint(AppColors.accentColor)
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .padding(.top, 40)
                } else {
                    switch selectedTab {
                    case .guild:
                        guildTab
                    case .global:
                        globalTab
                    case .history:
                        historyTab
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(AppColors.drawerBackground)
        .task {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reputationDidUpdate)) { _ in
            Task { await loadData() }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(RepTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? AppColors.accentColor.opacity(0.2) : Color.clear)
                    )
                    .foregroundColor(selectedTab == tab ? AppColors.accentColor : AppColors.greyText)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Guild Tab

    private var guildTab: some View {
        VStack(spacing: 16) {
            if let profile = guildProfile {
                // Tier Header
                tierHeader(
                    reputation: profile.reputation,
                    tier: profile.tier,
                    weeklyDelta: profile.weeklyDelta,
                    rank: profile.rankInGuild
                )

                // Progress to next tier
                tierProgressBar(currentRep: profile.reputation, currentTier: profile.tier)

                // Breakdown
                breakdownSection(profile.breakdown)

                // Daily Limits
                dailyLimitsSection(
                    predictionsToday: profile.predictionsToday,
                    socialCapRemaining: profile.dailySocialCapRemaining
                )

                // Recent Events
                if !profile.recentEvents.isEmpty {
                    recentEventsSection(profile.recentEvents)
                }

                // Leaderboard Preview
                if let lb = leaderboard, !lb.members.isEmpty {
                    leaderboardPreview(lb)
                }
            } else {
                Text("Not a member of this guild")
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
            }
        }
    }

    // MARK: - Global Tab

    private var globalTab: some View {
        VStack(spacing: 16) {
            if let global = globalReputation {
                // Tier Header
                tierHeader(
                    reputation: global.globalReputation,
                    tier: global.tier,
                    weeklyDelta: global.weeklyDelta,
                    rank: nil
                )

                // Progress to next tier
                tierProgressBar(currentRep: global.globalReputation, currentTier: global.tier)

                // Guild Contributions
                if !global.guildContributions.isEmpty {
                    guildContributionsSection(global.guildContributions)
                }

                // Modifiers
                modifiersSection(global.modifiers, streakDays: global.consecutiveActiveDays)
            } else {
                ProgressView()
                    .tint(AppColors.accentColor)
            }
        }
    }

    // MARK: - History Tab

    private var historyTab: some View {
        VStack(spacing: 12) {
            if historyEvents.isEmpty {
                Text("No reputation events yet")
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
                    .padding(.top, 20)
            } else {
                ForEach(historyEvents) { event in
                    historyEventRow(event)
                }

                if historyHasMore {
                    Button {
                        Task { await loadMoreHistory() }
                    } label: {
                        Text("Load More")
                            .font(.subheadline)
                            .foregroundColor(AppColors.accentColor)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // MARK: - Tier Header

    private func tierHeader(reputation: Int, tier: RLReputationTierDTO, weeklyDelta: Int, rank: Int?) -> some View {
        VStack(spacing: 12) {
            // Tier badge
            ZStack {
                Circle()
                    .fill(tier.color.opacity(0.2))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(tier.color, lineWidth: 2)
                    .frame(width: 64, height: 64)
                Text("\(tier.tierLevel)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(tier.color)
            }

            // Reputation score
            Text("\(reputation)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppColors.whiteText)

            Text("Tier \(tier.tierLevel)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(tier.color)

            // Weekly delta + rank
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: weeklyDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(weeklyDelta >= 0 ? "+" : "")\(weeklyDelta) this week")
                        .font(.caption)
                }
                .foregroundColor(weeklyDelta >= 0 ? .green : .red)

                if let rank = rank {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy")
                            .font(.caption2)
                        Text("Rank #\(rank)")
                            .font(.caption)
                    }
                    .foregroundColor(AppColors.greyText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tier.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Tier Progress Bar

    private func tierProgressBar(currentRep: Int, currentTier: RLReputationTierDTO) -> some View {
        Group {
            // Find next tier
            let nextTier = tiers.first(where: { $0.tierLevel == currentTier.tierLevel + 1 })

            if let next = nextTier {
                let progress = Double(currentRep - currentTier.minReputation) / Double(next.minReputation - currentTier.minReputation)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress to Tier \(next.tierLevel)")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Text("\(currentRep) / \(next.minReputation)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [currentTier.color, next.color],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1.0, max(0, progress)), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                )
            } else {
                // Max tier
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Maximum Tier Reached")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Breakdown Section

    private func breakdownSection(_ breakdown: RLReputationBreakdownDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Reputation Breakdown")

            ReputationBreakdownRow(
                title: "Predictions",
                value: breakdown.predictionRep,
                total: max(1, breakdown.total),
                color: .green
            )
            ReputationBreakdownRow(
                title: "Social",
                value: breakdown.socialRep,
                total: max(1, breakdown.total),
                color: .blue
            )
            ReputationBreakdownRow(
                title: "Activity",
                value: breakdown.activityRep,
                total: max(1, breakdown.total),
                color: .cyan
            )
            if breakdown.penaltyRep != 0 {
                ReputationBreakdownRow(
                    title: "Penalties",
                    value: breakdown.penaltyRep,
                    total: max(1, breakdown.total),
                    color: .red
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Daily Limits

    private func dailyLimitsSection(predictionsToday: Int, socialCapRemaining: Double) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(predictionsToday)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Text("Predictions Today")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
            )

            VStack(spacing: 4) {
                Text("\(Int(socialCapRemaining))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Text("Social Cap Left")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
            )
        }
    }

    // MARK: - Recent Events

    private func recentEventsSection(_ events: [RLReputationEventDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Recent Activity")

            ForEach(events.prefix(5)) { event in
                historyEventRow(event)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Event Row

    private func historyEventRow(_ event: RLReputationEventDTO) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.eventIcon)
                .font(.system(size: 14))
                .foregroundColor(event.eventColor)
                .frame(width: 28, height: 28)
                .background(event.eventColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayEventType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)
                Text(event.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer()

            Text(event.pointsFormatted)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(event.isPositive ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Leaderboard Preview

    private func leaderboardPreview(_ lb: RLReputationLeaderboardDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("Leaderboard")
                Spacer()
                Text("\(lb.totalMembers) members")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            ForEach(lb.members.prefix(5)) { member in
                HStack(spacing: 10) {
                    Text("#\(member.rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(member.rank <= 3 ? .yellow : AppColors.greyText)
                        .frame(width: 28)

                    Circle()
                        .fill(member.tier.color.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(member.tier.tierLevel)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(member.tier.color)
                        )

                    Text(member.displayName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                        .lineLimit(1)

                    Spacer()

                    Text("\(member.reputation)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Guild Contributions (Global Tab)

    private func guildContributionsSection(_ contributions: [RLGuildContributionDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Guild Contributions")

            ForEach(contributions, id: \.guildId) { guild in
                HStack(spacing: 12) {
                    // Weight badge
                    Text(guild.weightPercentFormatted)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(guild.guildName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("\(guild.reputation)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Modifiers (Global Tab)

    private func modifiersSection(_ modifiers: RLGlobalModifiersDTO, streakDays: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Active Modifiers")

            HStack(spacing: 12) {
                modifierCard(
                    icon: "checkmark.shield.fill",
                    title: "Clean Record",
                    value: modifiers.cleanRecordBonus ? "Active" : "Inactive",
                    detail: modifiers.cleanRecordBonus ? "x\(String(format: "%.2f", modifiers.cleanRecordMultiplier))" : "--",
                    color: modifiers.cleanRecordBonus ? .green : .gray
                )
                modifierCard(
                    icon: "bolt.fill",
                    title: "Streak",
                    value: "\(streakDays) days",
                    detail: "x\(String(format: "%.2f", modifiers.activityMultiplier))",
                    color: streakDays > 0 ? .cyan : .gray
                )
            }

            HStack {
                Text("Total Modifier")
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
                Spacer()
                Text("x\(String(format: "%.2f", modifiers.totalModifier))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func modifierCard(icon: String, title: String, value: String, detail: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.whiteText)
            Text(detail)
                .font(.caption2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.whiteText)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load tiers (for progress bar calculation)
            async let tiersTask = rlAppState.realApi.getReputationTiers()

            if let guildId = rlAppState.currentGuild?.id {
                async let profileTask = rlAppState.realApi.getMyGuildReputation(guildId: guildId)
                async let leaderboardTask = rlAppState.realApi.getGuildReputationLeaderboard(guildId: guildId, limit: 10)
                async let historyTask = rlAppState.realApi.getReputationHistory(guildId: guildId, page: 1, pageSize: 20)

                let (fetchedTiers, profile, lb, history) = try await (tiersTask, profileTask, leaderboardTask, historyTask)
                tiers = fetchedTiers
                guildProfile = profile
                leaderboard = lb
                historyEvents = history.events
                historyHasMore = history.hasMore
                historyPage = 1
            } else {
                tiers = try await tiersTask
            }

            // Always load global
            globalReputation = try await rlAppState.realApi.getMyGlobalReputation()

        } catch {
            errorMessage = "Failed to load reputation data"
            print("Reputation load error: \(error)")
        }

        isLoading = false
    }

    private func loadMoreHistory() async {
        guard historyHasMore else { return }
        let nextPage = historyPage + 1

        do {
            let history = try await rlAppState.realApi.getReputationHistory(
                guildId: rlAppState.currentGuild?.id,
                page: nextPage,
                pageSize: 20
            )
            historyEvents.append(contentsOf: history.events)
            historyHasMore = history.hasMore
            historyPage = nextPage
        } catch {
            print("Failed to load more history: \(error)")
        }
    }
}
