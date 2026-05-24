import SwiftUI

struct GlobalReputationBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLGlobalReputationDTO?
    @State private var recentEvents: [RLReputationEventDTO] = []
    @State private var lastUpdatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.guildReputationAccent).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Global Reputation")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text("\(profile.globalReputation)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(AppColors.whiteText)
                                Text("Tier \(profile.tier.tierLevel)")
                                    .font(.caption)
                                    .foregroundColor(profile.tier.color)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("Weekly")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text("\(profile.weeklyDelta >= 0 ? "+" : "")\(profile.weeklyDelta)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(profile.weeklyDelta >= 0 ? AppColors.statusPositive : AppColors.statusNegative)
                            }
                        }
                        HStack {
                            Spacer()
                            BreakdownFreshnessBadge(date: lastUpdatedAt)
                        }

                        StatTrendBars(
                            points: reputationTrendPoints(
                                from: profile.reputationTrend30d,
                                positiveTint: AppColors.guildReputationAccent
                            ),
                            centeredBaseline: true
                        )
                        .padding(.top, 10)
                    }

                    BreakdownCard(title: "Breakdown") {
                        HStack(alignment: .center, spacing: 14) {
                            StatDonut(
                                slices: breakdownDonutSlices(profile.breakdown),
                                centerText: "\(profile.breakdown.total)",
                                centerCaption: "Total",
                                size: 92
                            )

                            VStack(spacing: 10) {
                                StatProgressBar(label: "Prediction", valueText: "\(profile.breakdown.predictionRep)", progress: fraction(value: profile.breakdown.predictionRep, total: profile.breakdown.total), tint: AppColors.statusPositive)
                                StatProgressBar(label: "Social", valueText: "\(profile.breakdown.socialRep)", progress: fraction(value: profile.breakdown.socialRep, total: profile.breakdown.total), tint: AppColors.statusInfo)
                                if profile.breakdown.activityRep != 0 {
                                    StatProgressBar(label: "Activity", valueText: "\(profile.breakdown.activityRep)", progress: fraction(value: profile.breakdown.activityRep, total: profile.breakdown.total), tint: AppColors.guildReputationAccent)
                                }
                                if profile.breakdown.penaltyRep != 0 {
                                    StatProgressBar(label: "Penalties", valueText: "\(profile.breakdown.penaltyRep)", progress: fraction(value: abs(profile.breakdown.penaltyRep), total: max(1, abs(profile.breakdown.total))), tint: AppColors.statusNegative)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    BreakdownRulesCard(
                        title: "How Reputation Changes",
                        rules: reputationRuleItems()
                    )

                    BreakdownCard(title: "Guild Contributions") {
                        if profile.guildContributions.isEmpty {
                            Text("No contribution data yet")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(profile.guildContributions, id: \.guildId) { guild in
                                    StatProgressBar(
                                        label: guild.guildName,
                                        valueText: "\(guild.reputation)",
                                        progress: max(0, min(1, Double(guild.reputation) / Double(max(1, profile.globalReputation)))),
                                        tint: AppColors.guildReputationAccent
                                    )
                                }
                            }
                        }
                    }

                    BreakdownCard(title: "Modifiers") {
                        VStack(spacing: 10) {
                            BreakdownMetricRow(label: "Total Modifier", value: profile.modifiers.totalModifierFormatted, valueColor: AppColors.guildReputationAccent)
                            BreakdownMetricRow(label: "Clean Record", value: profile.modifiers.cleanRecordBonus ? "Yes" : "No", valueColor: profile.modifiers.cleanRecordBonus ? AppColors.statusPositive : AppColors.statusNegative)
                            BreakdownMetricRow(label: "Consecutive Active Days", value: "\(profile.consecutiveActiveDays)", valueColor: AppColors.whiteText)
                        }
                    }

                    if !recentEvents.isEmpty {
                        BreakdownCard(title: "Recent Impact") {
                            BreakdownImpactList(events: recentEvents)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .reputationDidUpdate)) { _ in
            Task { await loadData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard let userId = notification.userInfo?["userId"] as? UUID,
                  userId == rlAppState.currentUser?.id else { return }
            Task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let profileTask = rlAppState.realApi.getMyGlobalReputation()
            async let historyTask = rlAppState.realApi.getReputationHistory(page: 1, pageSize: 10)
            let (loadedProfile, history) = try await (profileTask, historyTask)
            profile = loadedProfile
            recentEvents = history.events.filter { $0.isVisibleActiveRuleEvent }
            lastUpdatedAt = Date()
        } catch {
            if error is CancellationError { return }
            errorMessage = RLUserFacingErrorMapper.message(from: error)
        }
    }
}

struct GlobalAccuracyBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLAccuracyProfileDTO?
    @State private var recentPredictionEvents: [RLReputationEventDTO] = []
    @State private var lastUpdatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.guildReputationAccent).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        HStack(alignment: .center, spacing: 14) {
                            StatGauge(
                                progress: profile.accuracyRate,
                                centerText: profile.accuracyFormatted,
                                captionText: "ACCURACY",
                                tint: breakdownAccuracyColor(profile.accuracyRate),
                                size: 104,
                                lineWidth: 10
                            )
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Global Accuracy")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text(profile.recordFormatted)
                                    .font(.headline)
                                    .foregroundColor(AppColors.whiteText)
                                if let rr = profile.rrRatioFormatted {
                                    Text("Avg R:R \(rr)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.moderationOrange)
                                }
                            }
                            Spacer(minLength: 0)
                        }

                        StatTrendBars(
                            points: accuracyTrendPoints(
                                from: profile.accuracyTrend30d,
                                tint: breakdownAccuracyColor(profile.accuracyRate)
                            ),
                            centeredBaseline: false
                        )
                        .padding(.top, 10)

                        HStack {
                            Spacer()
                            BreakdownFreshnessBadge(date: lastUpdatedAt)
                        }
                    }

                    BreakdownCard(title: "Performance") {
                        HStack(alignment: .center, spacing: 14) {
                            let losses = max(0, profile.totalPredictions - profile.successfulPredictions)
                            StatDonut(
                                slices: [
                                    StatDonutSlice(label: "Wins", value: Double(profile.successfulPredictions), tint: AppColors.statusPositive),
                                    StatDonutSlice(label: "Losses", value: Double(losses), tint: AppColors.statusNegative)
                                ],
                                centerText: "\(profile.totalPredictions)",
                                centerCaption: "Total",
                                size: 92
                            )

                            VStack(spacing: 8) {
                                BreakdownMetricRow(label: "Wins", value: "\(profile.successfulPredictions)", valueColor: AppColors.statusPositive)
                                BreakdownMetricRow(label: "Losses", value: "\(losses)", valueColor: AppColors.statusNegative)
                                BreakdownMetricRow(label: "Avg R:R", value: profile.rrRatioFormatted ?? "--", valueColor: AppColors.moderationOrange)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    BreakdownRulesCard(
                        title: "How Accuracy Changes",
                        rules: accuracyRuleItems()
                    )

                    BreakdownCard(title: "Streaks") {
                        HStack(spacing: 8) {
                            BreakdownMetricPill(label: "Win", value: "\(profile.winStreak)", tint: AppColors.statusPositive)
                            BreakdownMetricPill(label: "Loss", value: "\(profile.lossStreak)", tint: AppColors.statusNegative)
                            BreakdownMetricPill(label: "Best", value: "\(profile.bestWinStreak)", tint: AppColors.statusHighlight80)
                        }
                    }

                    if let rollingAccuracy = profile.rollingAccuracyFormatted {
                        BreakdownCard(title: "30-Day Rolling") {
                            HStack(spacing: 12) {
                                BreakdownMetricPill(label: "Accuracy", value: rollingAccuracy, tint: AppColors.guildReputationAccent)
                                BreakdownMetricPill(label: "Wins", value: "\(profile.rollingWins30d)", tint: AppColors.statusPositive)
                                BreakdownMetricPill(
                                    label: "Losses",
                                    value: "\(max(0, profile.rollingTotal30d - profile.rollingWins30d))",
                                    tint: AppColors.statusNegative
                                )
                            }
                        }
                    }

                    if !recentPredictionEvents.isEmpty {
                        BreakdownCard(title: "Recent Impact") {
                            BreakdownImpactList(events: recentPredictionEvents)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .accuracyDidUpdate)) { _ in
            Task { await loadData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard let userId = notification.userInfo?["userId"] as? UUID,
                  userId == rlAppState.currentUser?.id else { return }
            Task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let profileTask = rlAppState.realApi.getMyGlobalAccuracy()
            async let historyTask = rlAppState.realApi.getReputationHistory(page: 1, pageSize: 10)
            let (loadedProfile, history) = try await (profileTask, historyTask)
            profile = loadedProfile
            recentPredictionEvents = history.events.filter(\.isPredictionEvent)
            lastUpdatedAt = Date()
        } catch {
            if error is CancellationError { return }
            errorMessage = RLUserFacingErrorMapper.message(from: error)
        }
    }
}

struct GuildReputationBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLReputationProfileDTO?
    @State private var tiers: [RLReputationTierDTO] = []
    @State private var lastUpdatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.guildReputationAccent).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Guild Reputation")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text("\(profile.reputation)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(AppColors.whiteText)
                                Text("Tier \(profile.tier.tierLevel)")
                                    .font(.caption)
                                    .foregroundColor(profile.tier.color)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                if profile.rankInGuild > 0 {
                                    Text("Rank #\(profile.rankInGuild)")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.whiteText)
                                }
                                Text("\(profile.weeklyDelta >= 0 ? "+" : "")\(profile.weeklyDelta) this week")
                                    .font(.caption)
                                    .foregroundColor(profile.weeklyDelta >= 0 ? AppColors.statusPositive : AppColors.statusNegative)
                            }
                        }

                        HStack {
                            Spacer()
                            BreakdownFreshnessBadge(date: lastUpdatedAt)
                        }

                        StatTrendBars(
                            points: reputationTrendPoints(
                                from: profile.reputationTrend30d,
                                positiveTint: profile.tier.color
                            ),
                            centeredBaseline: true
                        )
                        .padding(.top, 10)
                    }

                    BreakdownCard(title: "Progress") {
                        if let nextTier = tiers.first(where: { $0.tierLevel == profile.tier.tierLevel + 1 }) {
                            let progress = Double(profile.reputation - profile.tier.minReputation) / Double(max(1, nextTier.minReputation - profile.tier.minReputation))
                            VStack(alignment: .leading, spacing: 8) {
                                BreakdownMetricRow(label: "To Tier \(nextTier.tierLevel)", value: "\(profile.reputation) / \(nextTier.minReputation)", valueColor: AppColors.whiteText)
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AppColors.symbolDetailCardFill)
                                        Capsule().fill(profile.tier.color)
                                            .frame(width: geometry.size.width * max(0, min(1, progress)))
                                    }
                                }
                                .frame(height: 8)
                            }
                        } else {
                            Text("Maximum tier reached")
                                .font(.subheadline)
                                .foregroundColor(AppColors.statusHighlight80)
                        }
                    }

                    BreakdownCard(title: "Breakdown") {
                        HStack(alignment: .center, spacing: 14) {
                            StatDonut(
                                slices: breakdownDonutSlices(profile.breakdown),
                                centerText: "\(profile.breakdown.total)",
                                centerCaption: "Total",
                                size: 92
                            )

                            VStack(spacing: 10) {
                                StatProgressBar(label: "Prediction", valueText: "\(profile.breakdown.predictionRep)", progress: fraction(value: profile.breakdown.predictionRep, total: profile.breakdown.total), tint: AppColors.statusPositive)
                                StatProgressBar(label: "Social", valueText: "\(profile.breakdown.socialRep)", progress: fraction(value: profile.breakdown.socialRep, total: profile.breakdown.total), tint: AppColors.statusInfo)
                                if profile.breakdown.activityRep != 0 {
                                    StatProgressBar(label: "Activity", valueText: "\(profile.breakdown.activityRep)", progress: fraction(value: profile.breakdown.activityRep, total: profile.breakdown.total), tint: AppColors.guildReputationAccent)
                                }
                                if profile.breakdown.penaltyRep != 0 {
                                    StatProgressBar(label: "Penalties", valueText: "\(profile.breakdown.penaltyRep)", progress: fraction(value: abs(profile.breakdown.penaltyRep), total: max(1, abs(profile.breakdown.total))), tint: AppColors.statusNegative)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    BreakdownRulesCard(
                        title: "How Reputation Changes",
                        rules: reputationRuleItems()
                    )

                    BreakdownCard(title: "Limits") {
                        BreakdownMetricRow(label: "Daily Social Cap Remaining", value: "\(Int(profile.dailySocialCapRemaining))", valueColor: AppColors.whiteText)
                    }

                    if !profile.recentEvents.isEmpty {
                        BreakdownCard(title: "Recent Impact") {
                            BreakdownImpactList(events: profile.recentEvents.filter { $0.isVisibleActiveRuleEvent })
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .reputationDidUpdate)) { _ in
            Task { await loadData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard let guildId = notification.userInfo?["guildId"] as? UUID,
                  guildId == rlAppState.currentGuild?.id else { return }
            Task { await loadData() }
        }
    }

    private func loadData() async {
        guard let guildId = rlAppState.currentGuild?.id else {
            errorMessage = "No guild selected"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let profileTask = rlAppState.realApi.getMyGuildReputation(guildId: guildId)
            async let tiersTask = rlAppState.realApi.getReputationTiers()
            let (loadedProfile, loadedTiers) = try await (profileTask, tiersTask)
            profile = loadedProfile
            tiers = loadedTiers
            lastUpdatedAt = Date()
        } catch {
            if error is CancellationError { return }
            errorMessage = RLUserFacingErrorMapper.message(from: error)
        }
    }

}

struct GuildAccuracyBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLAccuracyProfileDTO?
    @State private var recentPredictionEvents: [RLReputationEventDTO] = []
    @State private var lastUpdatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.guildReputationAccent).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        HStack(alignment: .center, spacing: 14) {
                            StatGauge(
                                progress: profile.accuracyRate,
                                centerText: profile.accuracyFormatted,
                                captionText: "ACCURACY",
                                tint: breakdownAccuracyColor(profile.accuracyRate),
                                size: 104,
                                lineWidth: 10
                            )
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Guild Accuracy")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text(profile.recordFormatted)
                                    .font(.headline)
                                    .foregroundColor(AppColors.whiteText)
                                if let rank = profile.rankInGuild {
                                    Text("Rank #\(rank)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.guildReputationAccent)
                                }
                                if let rr = profile.rrRatioFormatted {
                                    Text("Avg R:R \(rr)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.moderationOrange)
                                }
                            }
                            Spacer(minLength: 0)
                        }

                        StatTrendBars(
                            points: accuracyTrendPoints(
                                from: profile.accuracyTrend30d,
                                tint: breakdownAccuracyColor(profile.accuracyRate)
                            ),
                            centeredBaseline: false
                        )
                        .padding(.top, 10)

                        HStack {
                            Spacer()
                            BreakdownFreshnessBadge(date: lastUpdatedAt)
                        }
                    }

                    BreakdownCard(title: "Performance") {
                        HStack(alignment: .center, spacing: 14) {
                            let losses = max(0, profile.totalPredictions - profile.successfulPredictions)
                            StatDonut(
                                slices: [
                                    StatDonutSlice(label: "Wins", value: Double(profile.successfulPredictions), tint: AppColors.statusPositive),
                                    StatDonutSlice(label: "Losses", value: Double(losses), tint: AppColors.statusNegative)
                                ],
                                centerText: "\(profile.totalPredictions)",
                                centerCaption: "Total",
                                size: 92
                            )

                            VStack(spacing: 8) {
                                BreakdownMetricRow(label: "Wins", value: "\(profile.successfulPredictions)", valueColor: AppColors.statusPositive)
                                BreakdownMetricRow(label: "Losses", value: "\(losses)", valueColor: AppColors.statusNegative)
                                BreakdownMetricRow(label: "Avg R:R", value: profile.rrRatioFormatted ?? "--", valueColor: AppColors.moderationOrange)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    BreakdownRulesCard(
                        title: "How Accuracy Changes",
                        rules: accuracyRuleItems()
                    )

                    BreakdownCard(title: "Streaks") {
                        HStack(spacing: 8) {
                            BreakdownMetricPill(label: "Win", value: "\(profile.winStreak)", tint: AppColors.statusPositive)
                            BreakdownMetricPill(label: "Loss", value: "\(profile.lossStreak)", tint: AppColors.statusNegative)
                            BreakdownMetricPill(label: "Best", value: "\(profile.bestWinStreak)", tint: AppColors.statusHighlight80)
                        }
                    }

                    if let rollingAccuracy = profile.rollingAccuracyFormatted {
                        BreakdownCard(title: "30-Day Rolling") {
                            HStack(spacing: 12) {
                                BreakdownMetricPill(label: "Accuracy", value: rollingAccuracy, tint: AppColors.guildReputationAccent)
                                BreakdownMetricPill(label: "Wins", value: "\(profile.rollingWins30d)", tint: AppColors.statusPositive)
                                BreakdownMetricPill(
                                    label: "Losses",
                                    value: "\(max(0, profile.rollingTotal30d - profile.rollingWins30d))",
                                    tint: AppColors.statusNegative
                                )
                            }
                        }
                    }

                    if !recentPredictionEvents.isEmpty {
                        BreakdownCard(title: "Recent Impact") {
                            BreakdownImpactList(events: recentPredictionEvents)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .accuracyDidUpdate)) { _ in
            Task { await loadData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard let guildId = notification.userInfo?["guildId"] as? UUID,
                  guildId == rlAppState.currentGuild?.id else { return }
            Task { await loadData() }
        }
    }

    private func loadData() async {
        guard let guildId = rlAppState.currentGuild?.id else {
            errorMessage = "No guild selected"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let profileTask = rlAppState.realApi.getMyGuildAccuracy(guildId: guildId)
            async let historyTask = rlAppState.realApi.getReputationHistory(guildId: guildId, page: 1, pageSize: 10)
            let (loadedProfile, history) = try await (profileTask, historyTask)
            profile = loadedProfile
            recentPredictionEvents = history.events.filter(\.isPredictionEvent)
            lastUpdatedAt = Date()
        } catch {
            if error is CancellationError { return }
            errorMessage = RLUserFacingErrorMapper.message(from: error)
        }
    }
}

private struct BreakdownCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.symbolSheetGroupedPanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 0.8)
                )
        )
    }
}

private struct BreakdownSheetBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
        }
        .ignoresSafeArea()
    }
}

private struct BreakdownMetricRow: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

private struct BreakdownMetricPill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private func reputationTrendPoints(
    from trend: [RLReputationTrendPointDTO],
    positiveTint: Color
) -> [StatTrendBarPoint] {
    trend.map { point in
        StatTrendBarPoint(
            day: point.day,
            value: Double(point.value),
            tint: point.value >= 0 ? positiveTint : AppColors.statusNegative82
        )
    }
}

private func accuracyTrendPoints(
    from trend: [RLAccuracyTrendPointDTO],
    tint: Color
) -> [StatTrendBarPoint] {
    var previous: Double?
    return trend.map { point in
        let value = point.value
        let direction: Color
        if let previous {
            if value > previous + 0.0001 {
                direction = AppColors.statusPositive
            } else if value + 0.0001 < previous {
                direction = AppColors.statusNegative
            } else {
                direction = tint.opacity(0.6)
            }
        } else {
            direction = tint
        }
        previous = value
        return StatTrendBarPoint(
            day: point.day,
            value: value,
            tint: direction
        )
    }
}

private func breakdownAccuracyColor(_ value: Double) -> Color {
    if value >= 0.7 { return AppColors.statusPositive }
    if value >= 0.5 { return AppColors.statusHighlight80 }
    if value >= 0.3 { return AppColors.moderationOrange }
    return AppColors.statusNegative
}

/// Builds donut slices for the reputation breakdown. Penalties are tracked as
/// negative numbers on the DTO; visualise them by their magnitude alongside
/// the positive contributors so the donut always shows the full activity mix.
private func breakdownDonutSlices(_ breakdown: RLReputationBreakdownDTO) -> [StatDonutSlice] {
    var slices: [StatDonutSlice] = []
    if breakdown.predictionRep > 0 {
        slices.append(StatDonutSlice(label: "Prediction", value: Double(breakdown.predictionRep), tint: AppColors.statusPositive))
    }
    if breakdown.socialRep > 0 {
        slices.append(StatDonutSlice(label: "Social", value: Double(breakdown.socialRep), tint: AppColors.statusInfo))
    }
    if breakdown.activityRep > 0 {
        slices.append(StatDonutSlice(label: "Activity", value: Double(breakdown.activityRep), tint: AppColors.guildReputationAccent))
    }
    if breakdown.penaltyRep != 0 {
        slices.append(StatDonutSlice(label: "Penalties", value: Double(abs(breakdown.penaltyRep)), tint: AppColors.statusNegative))
    }
    return slices
}

private struct BreakdownRuleItem: Identifiable {
    let title: String
    let detail: String
    let tint: Color

    var id: String { title }
}

private func reputationRuleItems() -> [BreakdownRuleItem] {
    [
        BreakdownRuleItem(title: "Tracked setup result", detail: "Resolved TP and SL outcomes change reputation.", tint: AppColors.statusPositive),
        BreakdownRuleItem(title: "Marker likes", detail: "Likes add reputation and unlikes remove part of it.", tint: AppColors.moderationOrange),
        BreakdownRuleItem(title: "Marker comments", detail: "Comments on your marker add reputation while deleted comments reverse it.", tint: AppColors.statusInfo),
        BreakdownRuleItem(title: "Activity bonus", detail: "Daily participation and streak bonuses add reputation.", tint: AppColors.guildReputationAccent),
        BreakdownRuleItem(title: "Reports and decay", detail: "Moderation penalties and inactivity decay reduce reputation.", tint: AppColors.statusNegative),
    ]
}

private func accuracyRuleItems() -> [BreakdownRuleItem] {
    [
        BreakdownRuleItem(title: "TP hit", detail: "A resolved tracked setup that hits TP counts as a win.", tint: AppColors.statusPositive),
        BreakdownRuleItem(title: "SL hit", detail: "A resolved tracked setup that hits SL counts as a loss.", tint: AppColors.statusNegative),
        BreakdownRuleItem(title: "Expired setup", detail: "Expired tracked setups do not change accuracy.", tint: AppColors.greyText),
    ]
}

private func fraction(value: Int, total: Int) -> Double {
    guard total != 0 else { return 0 }
    return max(0, min(1, Double(abs(value)) / Double(abs(total))))
}

private struct BreakdownRulesCard: View {
    let title: String
    let rules: [BreakdownRuleItem]

    var body: some View {
        BreakdownCard(title: title) {
            VStack(spacing: 10) {
                ForEach(rules) { rule in
                    BreakdownRuleRow(rule: rule)
                }
            }
        }
    }
}

private struct BreakdownRuleRow: View {
    let rule: BreakdownRuleItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(rule.tint)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Text(rule.detail)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct BreakdownImpactList: View {
    let events: [RLReputationEventDTO]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(events.prefix(6)) { event in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: event.eventIcon)
                        .font(.caption)
                        .foregroundColor(event.eventColor)
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.displayEventType)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText)
                        Text(relativeTime(for: event.createdAt))
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }
                    Spacer()
                    Text(event.pointsFormatted)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(event.isPositive ? AppColors.statusPositive : AppColors.statusNegative)
                }
            }
        }
    }

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct BreakdownFreshnessBadge: View {
    let date: Date?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppColors.guildReputationAccent)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AppColors.symbolDetailCardFill)
        )
    }

    private var label: String {
        guard let date else { return "Live data" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

private extension RLReputationEventDTO {
    var isPredictionEvent: Bool {
        eventType == "prediction_win" || eventType == "prediction_loss"
    }

    var isVisibleActiveRuleEvent: Bool {
        switch eventType {
        case "prediction_win",
             "prediction_loss",
             "marker_liked",
             "marker_unliked",
             "marker_commented",
             "marker_comment_deleted",
             "activity_bonus",
             "streak_bonus",
             "decay",
             "report_penalty":
            return true
        default:
            return false
        }
    }
}
